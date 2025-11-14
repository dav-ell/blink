import { ChatLocation, RemoteChatInfo } from './device.js';

export class Chat {
    constructor(data) {
        this.id = data.chat_id || data.id || '';
        this.title = data.name || data.title || 'Untitled';
        this.createdAt = data.created_at_iso 
            ? new Date(data.created_at_iso)
            : (data.created_at ? new Date(data.created_at) : new Date());
        this.lastMessageAt = data.last_updated_at_iso
            ? new Date(data.last_updated_at_iso)
            : (data.last_updated_at ? new Date(data.last_updated_at) : new Date());
        this.messages = data.messages || [];
        this.isArchived = data.is_archived || false;
        this.isDraft = data.is_draft || false;
        this.totalLinesAdded = data.total_lines_added || 0;
        this.totalLinesRemoved = data.total_lines_removed || 0;
        this.subtitle = data.subtitle || null;
        this.messageCount = data.message_count || this.messages.length;
        this.location = data.location || ChatLocation.LOCAL;
        this.remoteInfo = data.device_id ? RemoteChatInfo.fromJson(data) : null;
    }

    get preview() {
        // For remote chats, use last_message_preview if available
        if (this.remoteInfo && this.remoteInfo.lastMessagePreview) {
            return this.remoteInfo.lastMessagePreview;
        }
        if (this.messages.length === 0) return 'No messages yet';
        const lastMessage = this.messages[this.messages.length - 1];
        return lastMessage.text || lastMessage.content || '';
    }

    get status() {
        if (this.isArchived) return 'archived';
        if (this.isDraft) return 'draft';
        return 'active';
    }

    get isRemote() {
        return this.location === ChatLocation.REMOTE;
    }

    get isLocal() {
        return this.location === ChatLocation.LOCAL;
    }

    static fromJson(json) {
        return new Chat(json);
    }
}

