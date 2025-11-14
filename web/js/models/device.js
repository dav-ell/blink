export const DeviceStatus = {
    ONLINE: 'online',
    OFFLINE: 'offline',
    UNKNOWN: 'unknown',
};

export const ChatLocation = {
    LOCAL: 'local',
    REMOTE: 'remote',
};

export class Device {
    constructor(data) {
        this.id = data.id || '';
        this.name = data.name || '';
        this.apiEndpoint = data.api_endpoint || '';
        this.apiKey = data.api_key || null;
        this.cursorAgentPath = data.cursor_agent_path || null;
        this.createdAt = data.created_at ? new Date(data.created_at) : new Date();
        this.lastSeen = data.last_seen ? new Date(data.last_seen) : null;
        this.isActive = data.is_active !== undefined ? data.is_active : true;
        this.status = data.status || DeviceStatus.UNKNOWN;
    }

    get isOnline() {
        return this.status === DeviceStatus.ONLINE;
    }

    get isOffline() {
        return this.status === DeviceStatus.OFFLINE;
    }

    get statusDisplayName() {
        switch (this.status) {
            case DeviceStatus.ONLINE:
                return 'Online';
            case DeviceStatus.OFFLINE:
                return 'Offline';
            default:
                return 'Unknown';
        }
    }

    get statusIcon() {
        switch (this.status) {
            case DeviceStatus.ONLINE:
                return '🟢';
            case DeviceStatus.OFFLINE:
                return '⚫';
            default:
                return '🟡';
        }
    }

    static fromJson(json) {
        return new Device(json);
    }
}

export class RemoteChatInfo {
    constructor(data) {
        this.chatId = data.chat_id || '';
        this.deviceId = data.device_id || '';
        this.deviceName = data.device_name || 'Unknown Device';
        this.deviceStatus = data.device_status || DeviceStatus.UNKNOWN;
        this.workingDirectory = data.working_directory || '';
        this.lastMessagePreview = data.last_message_preview || null;
    }

    get statusIcon() {
        switch (this.deviceStatus) {
            case DeviceStatus.ONLINE:
                return '🟢';
            case DeviceStatus.OFFLINE:
                return '⚫';
            default:
                return '🟡';
        }
    }

    static fromJson(json) {
        return new RemoteChatInfo(json);
    }
}

