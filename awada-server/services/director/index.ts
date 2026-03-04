/**
 * 导演指令处理服务
 * 处理导演发送的各种指令，如会员开通等
 */

import axios from 'axios';
import { WorkToolCallbackMessage } from '@/services/worktool/types';
import { sendTextMessage } from '@/services/worktool';
import { createLogger } from '../../src/utils/logger';
import { BotConfig } from '@/config/bots';
import { EventProducer, getConversationManager } from '../../src/infrastructure/redis';

const logger = createLogger('Director-Command');

/**
 * 导演昵称
 */
export const DIRECTOR_NICKNAME = ['无空', '-跟着感觉走'];

/**
 * 客服群
 */

export const CUSTOMER_SERVICE_GROUP = ['wiseflowPro 付费用户群', '测试群'];

/**
 * 会员群
 */
export const MEMBER_GROUP = ['wiseflowPro 付费用户群'];

/**
 * promotions 集合
 */
const PROMOTIONS_SET = new Set([
  'WEB',
  'AWADA',
  'XHS',
  'BILI',
  'SPH',
  'WX',
  'MP',
  'ZHIHU',
  'GITHUB',
  'QQ',
  'PR_001',
  'PR_002',
  'PR_003',
  'PR_004',
  'PR_005',
  'PR_006',
  'PR_007',
  'PR_008',
  'PR_009',
  'PR_010',
  'PR_011',
  'PR_012',
  'PR_013',
  'PR_014',
  'PR_015',
  'PR_016',
  'PR_017',
  'PR_018',
  'PR_019',
  'PR_020',
  'PR_021',
  'PR_022',
  'PR_023',
  'PR_024',
  'PR_025',
  'PR_026',
  'PR_027',
  'PR_028',
  'PR_029',
  'PR_030',
  'PR_031',
  'PR_032',
  'PR_033',
  'PR_034',
  'PR_035',
  'PR_036',
  'PR_037',
  'PR_038',
  'PR_039'
]);

/**
 * deal_type 集合
 */
const DEAL_TYPE_SET = new Set(['C_SUB', 'B_SUB', 'C_RENEW', 'B_RENEW', 'RP_001', 'RP_002', 'RP_003', 'RP_004', 'RP_005', 'RP_006', 'RP_007', 'RP_008', 'RP_009', 'RP_010', 'RP_011', 'RP_012', 'CP_001', 'CP_002', 'CP_003', 'CP_004', 'CP_005', 'CP_006', 'CP_007', 'CP_008', 'CP_009', 'CP_010', 'CP_011', 'CP_012', 'REFUND', 'OFFSET', 'TRIAL', 'EXP', 'OTHER', 'VIOLATE']);

/**
 * 会员开通指令参数
 */
export interface OnboardParams {
  user_email: string | null;
  user_mark: string | null;
  promotions: string | null;
  deal_type: string | null;
  deal_amount: number | null;
}

/**
 * 解析 /网站注册账号： 指令参数
 * 格式：
 * /网站注册账号：mao970825@gmail.com // {微信昵称} // {promotions} // {deal_type} // {deal_amount}
 *
 * 注意：
 * - 通过 // 分割各个字段
 * - 不需要判断字段数量，缺失的字段默认传 null
 */
export function parseOnboardCommand(messageText: string): OnboardParams | null {
  const parts = messageText
    .split('//')
    .map((part) => part.trim())
    .filter((part) => part);

  if (parts.length === 0) {
    return null;
  }

  // 第一部分必须是 /网站注册账号： 格式，并提取邮箱
  const firstPart = parts[0];
  const emailMatch = firstPart.match(/\/网站注册账号[：:]\s*(.+)/);
  if (!emailMatch) {
    return null;
  }

  const user_email = emailMatch[1].trim();

  // 初始化其他字段为 null
  let user_mark: string | null = null;
  let promotions: string | null = null;
  let deal_type: string | null = null;
  let deal_amount: number | null = null;

  // 从第二部分开始解析
  for (let i = 1; i < parts.length; i++) {
    const part = parts[i];

    // 尝试匹配 promotions
    if (!promotions) {
      const upperPart = part.toUpperCase();
      if (PROMOTIONS_SET.has(upperPart)) {
        promotions = upperPart;
        continue;
      }
    }

    // 尝试匹配 deal_type
    if (!deal_type) {
      const upperPart = part.toUpperCase();
      if (DEAL_TYPE_SET.has(upperPart)) {
        deal_type = upperPart;
        continue;
      }
    }

    // 尝试匹配 deal_amount
    if (deal_amount === null) {
      const amount = parseInt(part, 10);
      if (!isNaN(amount) && amount >= 0) {
        deal_amount = amount;
        continue;
      }
    }

    // 如果都不匹配，且 user_mark 还未设置，则作为微信昵称
    if (!user_mark) {
      user_mark = part;
    }
  }

  return {
    user_email,
    user_mark,
    promotions,
    deal_type,
    deal_amount
  };
}

/**
 * 拉用户入群
 */
async function addUserToGroup(robotId: string, groupName: string, userNickname: string): Promise<{ success: boolean; message?: string }> {
  try {
    const { worktoolClient } = await import('@/services/worktool');

    const list = [
      {
        type: 207, // 修改群信息(含拉人等)
        groupName: groupName,
        selectList: [userNickname] // 添加群成员名称列表（拉人）
      }
    ];

    const requestBody = {
      socketType: 2,
      list
    };

    const response = await worktoolClient.post<string>('/wework/sendRawMessage', requestBody, { params: { robotId } });

    if (response.code === 200) {
      return {
        success: true
      };
    } else {
      return {
        success: false,
        message: response.message || '拉人入群失败'
      };
    }
  } catch (error: any) {
    logger.error('拉人入群失败:', error);
    return {
      success: false,
      message: error.message || '拉人入群失败'
    };
  }
}

/**
 * 解析 /a 指令（设置群公告）
 * 格式：
 * /a // {需要设置为群公告的内容}
 *
 * 注意：通过 // 分割指令和内容
 */
export function parseAnnouncementCommand(messageText: string): string | null {
  const parts = messageText
    .split('//')
    .map((part) => part.trim())
    .filter((part) => part);

  if (parts.length < 2) {
    return null;
  }

  // 第一部分必须是 /a
  if (parts[0].toLowerCase() !== '/a') {
    return null;
  }

  // 第二部分及之后的内容是群公告内容（用 // 重新连接，保留原始格式）
  const announcement = parts.slice(1).join('//').trim();
  if (!announcement) {
    return null;
  }

  return announcement;
}

/**
 * 设置群公告
 * 使用 WorkTool 的 sendRawMessage 接口，type=207 表示修改群信息（含设置群公告）
 * 文档: https://app.apifox.com/web/project/1035094/apis/api-23520590
 * 
 * @param robotId 机器人ID
 * @param groupNames 群名称列表
 * @param announcement 公告内容
 * @returns 设置结果
 */
export async function setGroupAnnouncement(robotId: string, groupNames: string[], announcement: string): Promise<{ success: boolean; message?: string; failedGroups?: string[] }> {
  try {
    const { worktoolClient } = await import('@/services/worktool');

    // 为每个群名创建一个请求项
    const list = groupNames.map((groupName) => ({
      type: 207, // 修改群信息(含拉人等)
      groupName: groupName, // 待修改的群名（必须是 string）
      newGroupAnnouncement: announcement // 修改群公告
    }));

    const requestBody = {
      socketType: 2,
      list
    };

    const response = await worktoolClient.post<string>('/wework/sendRawMessage', requestBody, { params: { robotId } });

    if (response.code === 200) {
      return {
        success: true
      };
    } else {
      return {
        success: false,
        message: response.message || '设置群公告失败'
      };
    }
  } catch (error: any) {
    logger.error('设置群公告失败:', error);
    return {
      success: false,
      message: error.message || '设置群公告失败'
    };
  }
}

/**
 * 处理设置群公告指令
 */
export async function handleAnnouncementCommand(message: WorkToolCallbackMessage, robotId: string, announcement: string): Promise<void> {
  logger.info(`📢 处理设置群公告指令: ${announcement.substring(0, 50)}...`);

  // 设置群公告（允许通过私聊发送指令）
  const result = await setGroupAnnouncement(robotId, CUSTOMER_SERVICE_GROUP, announcement);

  if (result.success) {
    const successMessage = `✅ 群公告设置成功\n群名：${CUSTOMER_SERVICE_GROUP.join(',')}\n公告内容：\n${announcement}`;
    try {
      await sendTextMessage(robotId, {
        titleList: DIRECTOR_NICKNAME.filter((name) => name === message.receivedName),
        receivedContent: successMessage
      });
      logger.info(`✅ 群公告设置成功: ${CUSTOMER_SERVICE_GROUP.join(',')}`);
    } catch (error: any) {
      logger.error('发送成功消息失败:', error);
    }
  } else {
    const errorMessage = `❌ 群公告设置失败: ${result.message || '未知错误'}`;
    try {
      await sendTextMessage(robotId, {
        titleList: DIRECTOR_NICKNAME.filter((name) => name === message.receivedName),
        receivedContent: errorMessage
      });
      logger.error(`❌ 群公告设置失败: ${result.message}`);
    } catch (error: any) {
      logger.error('发送错误消息失败:', error);
    }
  }
}

/**
 * 检查是否是导演发送的消息
 */
export function isDirectorMessage(message: WorkToolCallbackMessage): boolean {
  return DIRECTOR_NICKNAME.includes(message.receivedName);
}
