import { Formatter } from '../utils/formatter.js';
import { MessageRole, MessageStatus } from '../models/message.js';

export function createMessageBubble(message) {
    const container = document.createElement('div');
    container.className = `message-bubble ${message.isUser ? 'user' : 'assistant'}`;

    // Tool calls (if any)
    if (message.toolCalls && message.toolCalls.length > 0) {
        message.toolCalls.forEach(toolCall => {
            const toolCallBox = createToolCallBox(toolCall);
            container.appendChild(toolCallBox);
        });
    }

    // Thinking content (if any)
    if (message.thinkingContent) {
        const thinkingBox = createThinkingBox(message.thinkingContent);
        container.appendChild(thinkingBox);
    }

    // Content badges (if using old format and has content)
    if (hasContentTypes(message)) {
        const badges = document.createElement('div');
        badges.style.display = 'flex';
        badges.style.gap = 'var(--spacing-xs)';
        badges.style.marginBottom = 'var(--spacing-xs)';
        
        if (message.hasCode) {
            badges.appendChild(createBadge('code', '📝 Code'));
        }
        if (message.hasTodos) {
            badges.appendChild(createBadge('todo', '✓ Todo'));
        }
        if (message.hasToolCall && (!message.toolCalls || message.toolCalls.length === 0)) {
            badges.appendChild(createBadge('tool', '🔧 Tool'));
        }
        if (message.hasThinking && !message.thinkingContent) {
            badges.appendChild(createBadge('thinking', '💭 Thinking'));
        }
        
        container.appendChild(badges);
    }

    // Processing indicator
    if (message.isProcessing) {
        const processingIndicator = createProcessingIndicator(
            message.getElapsedSeconds(),
            message.status === MessageStatus.PENDING
        );
        container.appendChild(processingIndicator);
    }

    // Message content (only if there's text)
    if (message.content && message.content.trim()) {
        const contentDiv = document.createElement('div');
        contentDiv.className = 'message-content';

        // Assistant label
        if (message.isAssistant) {
            const label = document.createElement('div');
            label.style.display = 'flex';
            label.style.alignItems = 'center';
            label.style.gap = 'var(--spacing-xs)';
            label.style.marginBottom = 'var(--spacing-sm)';
            label.style.fontSize = '12px';
            label.style.fontWeight = '600';
            label.style.color = 'var(--color-text-secondary)';
            label.innerHTML = '<span>✨</span><span>Cursor Assistant</span>';
            contentDiv.appendChild(label);
        }

        // Message text
        const textDiv = document.createElement('div');
        textDiv.style.lineHeight = '1.5';
        textDiv.style.whiteSpace = 'pre-wrap';
        textDiv.style.wordBreak = 'break-word';
        textDiv.textContent = message.content;
        contentDiv.appendChild(textDiv);

        // Error message for failed messages
        if (message.isFailed && message.errorMessage) {
            const errorDiv = document.createElement('div');
            errorDiv.style.marginTop = 'var(--spacing-sm)';
            errorDiv.style.padding = 'var(--spacing-sm)';
            errorDiv.style.background = 'rgba(239, 68, 68, 0.1)';
            errorDiv.style.borderRadius = 'var(--radius-sm)';
            errorDiv.style.border = '1px solid rgba(239, 68, 68, 0.3)';
            errorDiv.style.fontSize = '11px';
            errorDiv.style.color = 'var(--color-error)';
            errorDiv.innerHTML = `
                <div style="display: flex; align-items: center; gap: 4px;">
                    <span>⚠️</span>
                    <span>${escapeHtml(message.errorMessage)}</span>
                </div>
            `;
            contentDiv.appendChild(errorDiv);
        }

        // Timestamp and status
        const meta = document.createElement('div');
        meta.className = 'message-meta';
        meta.style.marginTop = 'var(--spacing-sm)';
        
        const statusIcon = getStatusIcon(message.status);
        meta.innerHTML = `
            <span>${statusIcon}</span>
            <span>${Formatter.formatTime(message.timestamp)}</span>
        `;
        contentDiv.appendChild(meta);

        container.appendChild(contentDiv);
    }

    return container;
}

function createToolCallBox(toolCall) {
    const box = document.createElement('div');
    box.className = 'tool-call-box';
    
    box.innerHTML = `
        <div class="tool-call-header">
            <span class="tool-call-title">🔧 ${escapeHtml(toolCall.name || 'Tool Call')}</span>
        </div>
        ${toolCall.arguments ? `
            <div class="tool-call-params">
                ${escapeHtml(JSON.stringify(toolCall.arguments, null, 2))}
            </div>
        ` : ''}
    `;
    
    return box;
}

function createThinkingBox(content) {
    const box = document.createElement('div');
    box.className = 'thinking-box';
    
    box.innerHTML = `
        <div class="thinking-header">
            <span class="thinking-title">💭 Thinking</span>
        </div>
        <div class="thinking-content">
            ${escapeHtml(content)}
        </div>
    `;
    
    return box;
}

function createBadge(type, text) {
    const badge = document.createElement('span');
    badge.className = `badge badge-${type}`;
    badge.textContent = text;
    return badge;
}

function createProcessingIndicator(elapsedSeconds, isPending) {
    const indicator = document.createElement('div');
    indicator.style.display = 'flex';
    indicator.style.alignItems = 'center';
    indicator.style.gap = 'var(--spacing-sm)';
    indicator.style.padding = 'var(--spacing-sm)';
    indicator.style.background = 'rgba(37, 99, 235, 0.1)';
    indicator.style.borderRadius = 'var(--radius-sm)';
    indicator.style.fontSize = '12px';
    indicator.style.color = 'var(--color-primary)';
    indicator.style.marginBottom = 'var(--spacing-xs)';
    
    const spinner = document.createElement('div');
    spinner.className = 'spinner';
    
    const text = document.createElement('span');
    if (isPending) {
        text.textContent = 'Pending...';
    } else if (elapsedSeconds !== null) {
        text.textContent = `Processing... ${Formatter.formatElapsedTime(elapsedSeconds)}`;
    } else {
        text.textContent = 'Processing...';
    }
    
    indicator.appendChild(spinner);
    indicator.appendChild(text);
    
    return indicator;
}

function hasContentTypes(message) {
    return message.hasCode || message.hasTodos || 
           message.hasToolCall || message.hasThinking;
}

function getStatusIcon(status) {
    switch (status) {
        case MessageStatus.PENDING:
            return '⏱️';
        case MessageStatus.SENDING:
            return '↗️';
        case MessageStatus.PROCESSING:
            return '⏳';
        case MessageStatus.COMPLETED:
            return '✓';
        case MessageStatus.FAILED:
            return '⚠️';
        default:
            return '•';
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

