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

    const list = form.querySelector('[data-tournament-players]');
    const add = form.querySelector('[data-tournament-add]');
    const template = form.querySelector('[data-tournament-player-template]');
    const maximum = Number(form.dataset.rosterMaximum);
    const update = () => {
        const players = Array.from(list.children);
        players.forEach((row, index) => {
            row.querySelector('[data-player-legend]').textContent = 'Compañero ' + (index + 1);
        });
        const filled = players.filter(row => Array.from(row.querySelectorAll('input')).every(field => field.value.trim() !== ''));
        const total = String(filled.length + 1);
        if (count.textContent !== total) count.textContent = total;
        add.disabled = players.length + 1 >= maximum;
    };

    add.addEventListener('click', () => {
        if (list.children.length + 1 >= maximum) return;
        const row = template.content.firstElementChild.cloneNode(true);
        list.append(row);
        update();
        row.querySelector('input').focus();
    });
    list.addEventListener('click', event => {
        const remove = event.target.closest('[data-tournament-remove]');
        if (!remove) return;
        const row = remove.closest('[data-tournament-player]');
        const next = row.nextElementSibling || row.previousElementSibling;
        row.remove();
        update();
        if (next) next.querySelector('input').focus();
        else if (!add.hidden) add.focus();
        else form.querySelector('button[type="submit"]')?.focus();
    });
    list.addEventListener('input', update);
    update();
});
