export const MessageRole = {
    USER: 'user',
    ASSISTANT: 'assistant',
};

export const MessageStatus = {
    PENDING: 'pending',
    SENDING: 'sending',
    PROCESSING: 'processing',
    COMPLETED: 'completed',
    FAILED: 'failed',
};

export class Message {
    constructor(data) {
        this.id = data.bubble_id || data.id || '';
        this.bubbleId = data.bubble_id || '';
        this.content = data.text || data.content || '';
        this.role = data.type_label === 'assistant' ? MessageRole.ASSISTANT : MessageRole.USER;
        this.timestamp = data.created_at ? new Date(data.created_at) : new Date();
        this.type = data.type || 1;
        this.typeLabel = data.type_label || 'user';
        
        // Content flags
        this.hasToolCall = data.has_tool_call || false;
        this.hasThinking = data.has_thinking || false;
        this.hasCode = data.has_code || false;
        this.hasTodos = data.has_todos || false;
        
        // Separated content
        this.toolCalls = data.tool_calls || null;
        this.thinkingContent = data.thinking_content || null;
        this.codeBlocks = data.code_blocks || null;
        this.todos = data.todos || null;
        
        // Status
        this.status = data.status || MessageStatus.COMPLETED;
        this.jobId = data.job_id || null;
        this.sentAt = data.sent_at ? new Date(data.sent_at) : null;
        this.processingStartedAt = data.processing_started_at 
            ? new Date(data.processing_started_at) 
            : null;
        this.completedAt = data.completed_at ? new Date(data.completed_at) : null;
        this.errorMessage = data.error_message || null;
    }

    get isUser() {
        return this.role === MessageRole.USER;
    }

    get isAssistant() {
        return this.role === MessageRole.ASSISTANT;
    }

    get isProcessing() {
        return this.status === MessageStatus.SENDING || 
               this.status === MessageStatus.PROCESSING;
    }

    get isCompleted() {
        return this.status === MessageStatus.COMPLETED;
    }

    get isFailed() {
        return this.status === MessageStatus.FAILED;
    }

    getElapsedSeconds() {
        if (!this.processingStartedAt) return null;
        const endTime = this.completedAt || new Date();
        return (endTime - this.processingStartedAt) / 1000;
    }

    static fromJson(json) {
        return new Message(json);
    }
}

