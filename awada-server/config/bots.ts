/**
 * Bot 配置管理
 * 支持多个 Bot 实例，每个 Bot 有独立的 token 和 deviceGuid
 */

import { Lane, Platform } from '@/src/infrastructure/redis/types';
import { createLogger } from '../src/utils/logger';

const logger = createLogger('BotConfig');

export interface BotConfig {
  type: 'qiwe' | 'worktool';
  /** Bot 唯一标识 */
  botId: string;
  /** QiweAPI Token */
  token: string;
  /** 设备 GUID */
  deviceGuid: string;
  /** 该 Bot 监听的 lanes */
  lanes: Lane[];
  /** 平台标识 */
  platform: Platform;
  /** Bot 名称（可选） */
  name?: string;
  /** Bot 的 userId（wxid），启动时获取并缓存 */
  userId?: string;
}

/**
 * 从环境变量加载 Bot 配置
 */
function loadBotConfigs(): BotConfig[] {
  const bots: BotConfig[] = [];

  // Bot 1: linfen
  if (process.env.LINFEN_TOKEN && process.env.LINFEN_DEVICE_GUID) {
    bots.push({
      type: 'qiwe',
      botId: 'linfen',
      token: process.env.LINFEN_TOKEN,
      deviceGuid: process.env.LINFEN_DEVICE_GUID,
      lanes: ['linfen', 'admin'],
      platform: 'qiwe:linxiaozhu',
      name: 'linfen'
    });
    logger.info('✅ 加载 Bot 配置: linfen (platform: qiwe:linxiaozhu, lanes: linfen, admin)');
  } else {
    logger.warn('⚠️ 未配置 LINFEN_TOKEN 或 LINFEN_DEVICE_GUID');
  }

  // Bot 2: wiseflow
  //   if (process.env.WISEFLOW_TOKEN && process.env.WISEFLOW_DEVICE_GUID) {
  //     bots.push({
  //       botId: 'wiseflow',
  //       token: process.env.WISEFLOW_TOKEN,
  //       deviceGuid: process.env.WISEFLOW_DEVICE_GUID,
  //       lanes: ['wiseflow', 'admin'],
  //       platform: 'qiwe:wiseflow',
  //       name: 'wiseflow'
  //     });
  //     logger.info('✅ 加载 Bot 配置: wiseflow (platform: qiwe:wiseflow, lanes: wiseflow, admin)');
  //   } else {
  //     logger.warn('⚠️ 未配置 WISEFLOW_TOKEN 或 WISEFLOW_DEVICE_GUID');
  //   }

  // WorkTool Bot
  // ⚠️ TODO: 根据 WorkTool API 文档确认配置字段（robotId、token 等）
  // 需要查看文档确认：
  // 1. WorkTool 使用什么字段作为 Bot 标识（robotId？）
  // 2. 认证方式（token？）
  // 3. 其他必需配置
  if (process.env.WISEFLOW_BOT_ID) {
    bots.push({
      type: 'worktool',
      botId: 'wiseflow',
      token: '',
      deviceGuid: process.env.WISEFLOW_BOT_ID || '',
      lanes: ['user', 'admin'],
      platform: 'worktool:wiseflow', // ⚠️ 需要根据实际需求调整
      name: 'wiseflow'
    });
    logger.info('✅ 加载 WorkTool Bot 配置: worktool-1');
  } else {
    logger.warn('⚠️ 未配置 WORKTOOL_ROBOT_ID 或 WORKTOOL_TOKEN');
  }

  return bots;
}

/**
 * 所有 Bot 配置
 */
export const BOT_CONFIGS: BotConfig[] = loadBotConfigs();

/**
 * 导出配置加载函数，供测试使用
 */
export { loadBotConfigs };
