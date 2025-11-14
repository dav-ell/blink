export function createToolCallBox(toolCall) {
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

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

