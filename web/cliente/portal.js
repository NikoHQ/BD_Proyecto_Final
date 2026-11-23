'use strict';

document.addEventListener('change', event => {
    const radio = event.target;
    if (radio.name !== 'slot' || !radio.checked) return;
    for (const field of ['court', 'time', 'total']) {
        document.getElementById('selected-' + field).textContent = radio.dataset[field];
    }
});

document.querySelectorAll('[data-once]').forEach(form => {
    form.addEventListener('submit', () => {
        const button = form.querySelector('button');
        button.dataset.originalText = button.textContent;
        button.disabled = true;
        button.textContent = 'Enviando…';
    });
});

window.addEventListener('pageshow', event => {
    if (!event.persisted) return;
    for (const button of document.querySelectorAll('[data-once] button')) {
        button.disabled = false;
        button.textContent = button.dataset.originalText || button.textContent;
    }
});

document.querySelector('[data-copy]')?.addEventListener('click', async event => {
    const code = event.currentTarget.dataset.copy;
    const status = document.querySelector('.copy-status');
    try {
        await navigator.clipboard.writeText(code);
        status.textContent = 'Código copiado.';
    } catch {
        status.textContent = 'Tu código es ' + code + '.';
    }
});

document.querySelectorAll('[data-tournament-roster]').forEach(form => {
    const count = form.querySelector('[data-tournament-count]');
    if (!count) return;

    const players = Array.from(form.querySelectorAll('[data-tournament-player]'));
    const update = () => {
        const filled = players.filter(row => Array.from(row.querySelectorAll('input')).every(field => field.value.trim() !== ''));
        const total = String(filled.length + 1);
        if (count.textContent !== total) count.textContent = total;
    };
    form.addEventListener('input', update);
    update();
});
