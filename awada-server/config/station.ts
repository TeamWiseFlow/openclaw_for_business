// 情报小站配置

/**
 * 情报小站群信息
 */
export interface StationRoomType {
    room: {
        name: string;
        groupId: string;
    };
}


const StationConfig = {
    welComeStation: `👋 {name}，欢迎加入 {group_name}！\n
🤖 AI 首席情报官将每日为您呈现行业最新消息（原始信源来自本群网友提交，经 wiseflow 程序智能下钻提取）\n
💡 如您有个性化信息获取需求，请添加我私聊咨询\n
📌 群内主要进行行业信息交流与探讨，请您遵守群主相关约定，感谢配合\n
🚀 躺赢信息战，你的热 AI 领航`
}


export default StationConfig;