'use strict';

const $ = id => document.getElementById(id);
const icon = name => `<i class="bi bi-${name}" aria-hidden="true"></i>`;
const escapeHtml = value => String(value).replace(/[&<>"']/g, char => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[char]));
const money = new Intl.NumberFormat('es-CL', { style: 'currency', currency: 'CLP' });
const dateLabel = new Intl.DateTimeFormat('es-CL', { dateStyle: 'full' });
const chileClock = new Intl.DateTimeFormat('sv-SE', {
  timeZone: 'America/Santiago', year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit', hourCycle: 'h23'
});
const localClock = () => chileClock.format(new Date()).split(' ');
const initialDay = localClock()[0];
function minutes(time) {
  const [hours, mins] = time.split(':').map(Number);
  return hours * 60 + mins;
}
const shortDay = new Intl.DateTimeFormat('es-CL', { day: 'numeric', month: 'short', weekday: 'short' });
const dayLabel = day => shortDay.format(new Date(`${day}T12:00:00`));
const normalizeName = value => value.trim().toLowerCase().normalize('NFD').replace(/\p{M}/gu, '');
const compactRut = value => value.trim().toUpperCase().replace(/[.\s-]/g, '');
function parseRut(value) {
  const compact = compactRut(value);
  if (!/^[1-9]\d{0,7}[0-9K]$/.test(compact)) return null;
  const digits = compact.slice(0, -1);
  const rut = rutWithDigit(digits);
  return compact.endsWith(rut.at(-1)) ? rut : null;
}
function rutWithDigit(digits) {
  const sum = [...digits].reverse().reduce((total, digit, index) => total + Number(digit) * (2 + index % 6), 0);
  return digits + '-' + '0K987654321'[sum % 11];
}
