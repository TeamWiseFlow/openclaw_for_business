/**
 * 分组管理服务
 * 处理分组创建等操作
 */

import axios from 'axios';
import { WorkToolCallbackMessage } from '@/services/worktool/types';
import { createLogger } from '../../src/utils/logger';
import { sendTextMessage } from '@/services/worktool';
import { shouldProcessMessage } from '@/src/routes/webhook-worktool';
import { DIRECTOR_NICKNAME, setGroupAnnouncement } from './index';
import StationConfig, { StationRoomType } from '@/config/station';
import * as fs from 'fs';
import * as path from 'path';

const logger = createLogger('Director-Group');

// 情报小站数据文件路径
const STATION_DATA_FILE = path.join(process.cwd(), 'database', 'worktool', 'station.json');

/**
 * 获取所有情报小站群名称列表
 * @returns 群名称数组
 */
export function getAllStationRoomNames(): string[] {
    try {
        if (!fs.existsSync(STATION_DATA_FILE)) {
            logger.warn('情报小站数据文件不存在');
            return [];
        }

        const data = fs.readFileSync(STATION_DATA_FILE, 'utf-8');
        const stations: StationRoomType[] = JSON.parse(data);

        return stations.map((station) => station.room.name);
    } catch (error: any) {
        logger.error('获取情报小站群列表失败:', error);
        return [];
    }
}

/**
 * 创建分组接口响应
 */
interface CreateGroupResponse {
    success: boolean;
    msg: string;
    group_id: string;
}

/**
 * 创建分组结果
 */
export interface CreateGroupResult {
    success: boolean;
    message?: string;
    groupId?: string;
}

/**
 * 创建分组
 * 通过调用 backend 的 /create_group 接口创建分组，避免 group_id 冲突
 *
 * @param robotId 机器人ID（未使用，保留用于未来扩展）
 * @param message 回调消息（包含群聊信息）
 * @returns 创建结果
 */
export async function createGroup(robotId: string, message: WorkToolCallbackMessage): Promise<CreateGroupResult> {
    const directorAgentToken = process.env.WISEFLOW_ES_API_TOKEN;
    const userAgent = process.env.WISEFLOW_ES_USER_AGENT;
    const backendBaseUrl = process.env.WISEFLOW_ES_API_URL;

    if (!directorAgentToken || !userAgent || !backendBaseUrl) {
        logger.error('WISEFLOW_ES_API_TOKEN、WISEFLOW_ES_USER_AGENT、WISEFLOW_ES_BASE_URL 环境变量未设置');
        return {
            success: false,
            message: 'WISEFLOW_ES_API_TOKEN、WISEFLOW_ES_USER_AGENT、WISEFLOW_ES_BASE_URL 环境变量未设置'
        };
    }

    try {
        // 构建请求体
        // 现阶段 user_list 都留空
        const requestBody: {
            group_name?: string;
            admin_list?: string[];
            user_list?: string[];
        } = {
            group_name: message.groupName,
            admin_list: ['689f3724-7ae1-488d-bbd4-acbdff83c344', 'a5306f8c-325e-4985-a455-271bd61ed274'],
            user_list: []
        };

        const response = await axios.post<CreateGroupResponse>(`${backendBaseUrl}/create_group`, requestBody, {
            headers: {
                Authorization: `Bearer ${directorAgentToken}`,
                'User-Agent': userAgent,
                'Content-Type': 'application/json'
            },
            timeout: 30000 // 30秒超时
        });

        if (response.data.success) {
            const groupId = response.data.group_id;
            logger.info(`✅ 分组创建成功，group_id: ${groupId}`);
            return {
                success: true,
                groupId: groupId
            };
        } else {
            const errorMsg = response.data.msg || '创建分组失败';
            logger.error(`❌ 创建分组失败: ${errorMsg}`);
            return {
                success: false,
                message: errorMsg
            };
        }
    } catch (error: any) {
        logger.error('调用创建分组 API 失败:', error);
        const errorMessage = error.response?.data?.msg || error.message || 'API 请求失败';
        return {
            success: false,
            message: errorMessage
        };
    }
}


/**
 * 保存情报小站群信息
 * @param groupName 群名称
 * @param groupId 组ID
 */
function saveStationRoom(groupName: string, groupId: string): void {
    try {
        // 确保目录存在
        const dir = path.dirname(STATION_DATA_FILE);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }

        // 读取现有数据
        let stations: StationRoomType[] = [];
        if (fs.existsSync(STATION_DATA_FILE)) {
            const data = fs.readFileSync(STATION_DATA_FILE, 'utf-8');
            stations = JSON.parse(data);
        }

        // 检查是否已存在
        const exists = stations.some((station) => station.room.name === groupName);
        if (!exists) {
            // 添加新的情报小站群
            stations.push({
                room: {
                    name: groupName,
                    groupId: groupId
                }
            });

            // 保存到文件
            fs.writeFileSync(STATION_DATA_FILE, JSON.stringify(stations, null, 2), 'utf-8');
            logger.info(`✅ 情报小站群已保存: ${groupName}`);
        } else {
            logger.info(`ℹ️ 情报小站群已存在: ${groupName}`);
        }
    } catch (error: any) {
        logger.error('保存情报小站群信息失败:', error);
        throw error;
    }
}

/**
 * 解析 /cg 指令（创建分组）
 * 格式：
 * /cg
 *
 * 注意：指令为 /cg，不需要额外参数
 */
export function parseCreateGroupCommand(messageText: string): boolean {
    const normalizedMessage = messageText.trim().toLowerCase();

    // 精确匹配 /cg
    return normalizedMessage === '/cg';
}

/**
 * 解析 /a-station 指令（设置情报小站群公告）
 * 格式：
 * /a-station//{公告内容}
 * 
 * @param messageText 消息文本
 * @returns 公告内容，如果不是该指令则返回 null
 */
export function parseStationAnnouncementCommand(messageText: string): string | null {
    const normalizedMessage = messageText.trim();

    // 检查是否以 /a-station// 开头
    if (!normalizedMessage.startsWith('/a-station//')) {
        return null;
    }

    // 按 // 分割
    const parts = normalizedMessage.split('//');
    if (parts.length < 2) {
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
 * 处理设置情报小站群公告指令
 * 
 * @param message 回调消息
 * @param robotId 机器人ID
 * @param announcement 公告内容
 */
export async function handleStationAnnouncementCommand(
    message: WorkToolCallbackMessage,
    robotId: string,
    announcement: string
): Promise<void> {
    logger.info(`📢 处理设置情报小站群公告指令: ${announcement.substring(0, 50)}...`);

    // 获取所有情报小站群列表
    const stationGroups = getAllStationRoomNames();

    if (stationGroups.length === 0) {
        const errorMessage = `❌ 未找到任何情报小站群`;
        try {
            await sendTextMessage(robotId, {
                titleList: DIRECTOR_NICKNAME.filter((name) => name === message.receivedName),
                receivedContent: errorMessage
            });
            logger.warn(`⚠️ 未找到任何情报小站群`);
        } catch (error: any) {
            logger.error('发送错误消息失败:', error);
        }
        return;
    }

    // 批量设置群公告（复用现有的 setGroupAnnouncement 方法）
    const result = await setGroupAnnouncement(robotId, stationGroups, announcement);

    if (result.success) {
        const successMessage = `✅ 情报小站群公告设置成功\n共 ${stationGroups.length} 个群\n公告内容：\n${announcement}`;
        try {
            await sendTextMessage(robotId, {
                titleList: DIRECTOR_NICKNAME.filter((name) => name === message.receivedName),
                receivedContent: successMessage
            });
            logger.info(`✅ 情报小站群公告设置成功: ${stationGroups.join(', ')}`);
        } catch (error: any) {
            logger.error('发送成功消息失败:', error);
        }
    } else {
        const errorMessage = `❌ 情报小站群公告设置失败: ${result.message || '未知错误'}`;
        try {
            await sendTextMessage(robotId, {
                titleList: DIRECTOR_NICKNAME.filter((name) => name === message.receivedName),
                receivedContent: errorMessage
            });
            logger.error(`❌ 情报小站群公告设置失败: ${result.message}`);
        } catch (error: any) {
            logger.error('发送错误消息失败:', error);
        }
    }
}

/**
 * 处理创建分组指令
 */
export async function handleCreateGroupCommand(message: WorkToolCallbackMessage, robotId: string): Promise<void> {
    logger.info(`📦 处理创建分组指令`);
    const isAtRobot = shouldProcessMessage(message, robotId);
    // 检查是否在群聊中
    const isGroupChat = message.roomType === 1 || message.roomType === 3;
    if (!isGroupChat) {
        const errorMessage = `❌ 创建分组指令只能在群聊中使用`;
        try {
            await sendTextMessage(robotId, {
                titleList: DIRECTOR_NICKNAME.filter((name) => name === message.receivedName),
                receivedContent: errorMessage
            });
            logger.warn(`⚠️ 创建分组指令只能在群聊中使用`);
        } catch (error: any) {
            logger.error('发送错误消息失败:', error);
        }
        return;
    }

    // 检查是否@了机器人
    if (!isAtRobot) {
        const errorMessage = `❌ 创建分组指令需要@机器人`;
        try {
            await sendTextMessage(robotId, {
                titleList: DIRECTOR_NICKNAME.filter((name) => name === message.receivedName),
                receivedContent: errorMessage
            });
            logger.warn(`⚠️ 创建分组指令需要@机器人`);
        } catch (error: any) {
            logger.error('发送错误消息失败:', error);
        }
        return;
    }

    // 调用创建分组函数
    const result = await createGroup(robotId, message);

    if (result.success) {
        try {
            // 1. 保存情报小站群信息
            saveStationRoom(message.groupName, result.groupId || '');

            // 2. 发送成功消息给导演
            const successMessage = `✅ 分组创建成功\n组ID：${result.groupId || '未知'}\n群名：${message.groupName}`;
            await sendTextMessage(robotId, {
                titleList: DIRECTOR_NICKNAME.filter((name) => name === message.receivedName),
                receivedContent: successMessage
            });
            logger.info(`✅ 分组创建成功，group_id: ${result.groupId}`);

            // 3. 在群里发送欢迎消息
            // 替换欢迎消息模板中的变量
            const welcomeMessage = StationConfig.welComeStation
                .replace('{name}', '各位群友')
                .replace('{group_name}', message.groupName);

            await sendTextMessage(robotId, {
                titleList: [message.groupName],
                receivedContent: welcomeMessage
            });
            logger.info(`✅ 欢迎消息已发送到群: ${message.groupName}`);
        } catch (error: any) {
            logger.error('处理分组创建成功后的操作失败:', error);
            // 发送错误通知给导演
            const errorMessage = `⚠️ 分组创建成功，但后续操作失败: ${error.message}`;
            try {
                await sendTextMessage(robotId, {
                    titleList: DIRECTOR_NICKNAME.filter((name) => name === message.receivedName),
                    receivedContent: errorMessage
                });
            } catch (notifyError: any) {
                logger.error('发送错误通知失败:', notifyError);
            }
        }
    } else {
        const errorMessage = `❌ 分组创建失败: ${result.message || '未知错误'}`;
        try {
            await sendTextMessage(robotId, {
                titleList: DIRECTOR_NICKNAME.filter((name) => name === message.receivedName),
                receivedContent: errorMessage
            });
            logger.error(`❌ 分组创建失败: ${result.message}`);
        } catch (error: any) {
            logger.error('发送错误消息失败:', error);
        }
    }
}
