import { applyPrank, calmDown, rankFor } from './game-core.js';

const $ = selector => document.querySelector(selector);
const $$ = selector => [...document.querySelectorAll(selector)];
let state = { heat: 0, suspicion: 0, combo: 1, completed: new Set() };
let started = false;
let busy = false;
let selected = 'sticker';
let minute = 42;
let routeTimer;

const actions = {
  screen: { task: 'screen', item: 'sticker', heat: 24, suspicion: 18, x: 20, text: 'На экране Лены застыло «Обновление 99%»' },
  folders: { task: 'folders', item: 'sticker', heat: 18, suspicion: 12, x: 34, text: 'В идеальной системе папок появился маленький хаос' },
  coffee: { task: 'coffee', item: 'sticker', heat: 28, suspicion: 15, x: 67, text: 'Кофемашина начала торжественную самоочистку' },
  printer: { task: 'printer', item: 'paper', heat: 35, suspicion: 23, x: 88, text: 'Вместо отчёта вышел меморандум о важности обеда' },
};

const routes = {
  lena: [{ left: 18, bottom: 7 }, { left: 46, bottom: 7 }, { left: 23, bottom: 7 }],
  marina: [{ left: 35, bottom: 7 }, { left: 65, bottom: 7 }, { left: 38, bottom: 7 }],
  pasha: [{ left: 82, bottom: 7 }, { left: 48, bottom: 7 }, { left: 86, bottom: 7 }],
};
const routeIndex = { lena: 0, marina: 0, pasha: 0 };

function toast(text, danger = false) {
  const node = $('#toast');
  node.textContent = text;
  node.classList.toggle('danger-toast', danger);
  node.classList.add('show');
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => node.classList.remove('show'), 2400);
}

function render() {
  const heat = Math.round(state.heat);
  const suspicion = Math.round(state.suspicion);
  $('#heatBar').style.width = `${heat}%`;
  $('#susBar').style.width = `${suspicion}%`;
  $('#heatLabel').textContent = `${heat}%`;
  $('#susLabel').textContent = `${suspicion}%`;
  $('#combo').textContent = `×${state.combo}`;
  $('#taskCount').textContent = `${Math.min(state.completed.size, 3)} / 3`;
  $('#dot2').classList.toggle('done', state.completed.size > 0);
  $('#dot3').classList.toggle('done', state.completed.size > 1);
  const goals = ['Изучи маршрут Паши и подготовь первую пакость', 'Отвлеки коллег и устрой вторую пакость', 'Заверши цепочку и включи невинное лицо', 'Цепочка готова — не попадись!'];
  $('#objectiveText').textContent = goals[Math.min(state.completed.size, 3)];
}

function moveDima(x) {
  $('#dima').style.left = `${x}%`;
}

function perform(btn) {
  if (!started) return toast('Сначала начни рабочий день');
  if (busy) return toast('Дима уже что-то замышляет');
  const action = actions[btn.dataset.action];
  if (selected !== action.item) {
    const required = action.item === 'paper' ? 'шуточный лист' : 'стикеры';
    return toast(`Нужен предмет: ${required}`, true);
  }
  busy = true;
  moveDima(action.x);
  $('#actionName').textContent = btn.querySelector('em').textContent;
  $('#actionProgress').classList.add('show');
  setTimeout(() => {
    state = applyPrank(state, action);
    btn.classList.add('used');
    $('#actionProgress').classList.remove('show');
    $('#bubble').textContent = ['Оп!', 'Хе-хе…', 'По плану!'][Math.min(state.completed.size - 1, 2)];
    $('#bubble').classList.add('show');
    setTimeout(() => $('#bubble').classList.remove('show'), 1300);
    toast(`КОМБО ×${state.combo} · ${action.text}`);
    busy = false;
    render();
    if (state.completed.size >= 3) setTimeout(win, 1700);
  }, 1100);
}

function isCaught(npc) {
  const dimaX = parseFloat($('#dima').style.left || 48);
  const npcX = npc.offsetLeft / $('#office').clientWidth * 100;
  return busy && Math.abs(dimaX - npcX) < 11;
}

function patrol() {
  if (!started || busy && state.suspicion >= 100) return;
  $$('.npc').forEach((npc, offset) => {
    const name = npc.dataset.npc;
    routeIndex[name] = (routeIndex[name] + 1) % routes[name].length;
    const point = routes[name][routeIndex[name]];
    setTimeout(() => {
      npc.style.left = `${point.left}%`;
      npc.classList.add('walking');
      setTimeout(() => npc.classList.remove('walking'), 1500);
      if (isCaught(npc)) {
        state = { ...state, suspicion: Math.min(100, state.suspicion + 28), combo: 1 };
        npc.classList.add('suspicious');
        toast(`${npc.querySelector('small').textContent} что-то заметил(а)! +28 палева`, true);
        render();
        if (state.suspicion >= 100) setTimeout(lose, 500);
        setTimeout(() => npc.classList.remove('suspicious'), 1800);
      }
    }, offset * 450);
  });
}

function innocent() {
  if (!started || busy) return;
  state = calmDown(state);
  $('#bubble').textContent = 'Я? Да вы что.';
  $('#bubble').classList.add('show');
  $('#dima').classList.add('innocent-pose');
  toast('−22 палева · Максимально непричастный вид');
  setTimeout(() => { $('#bubble').classList.remove('show'); $('#dima').classList.remove('innocent-pose'); }, 1600);
  render();
}

function finish(won) {
  started = false;
  clearInterval(routeTimer);
  $('#resultKicker').textContent = won ? 'ПЯТНИЦА · 18:01' : 'ТЕБЯ РАСКУСИЛИ';
  $('#resultTitle').textContent = won ? 'Рабочая неделя завершена' : 'Слишком много палева';
  $('#finalHeat').textContent = Math.round(state.heat);
  $('#finalTasks').textContent = `${state.completed.size}/3`;
  $('#finalRank').textContent = rankFor(state.heat);
  $('#resultText').textContent = won ? 'Паша изучает отчёт, Лена поправляет папки, Марина смеётся. Все смотрят на Диму. Дима смотрит в окно.' : 'Коллеги сопоставили факты. Попробуй отвлекать их маршрутами и чаще включать невинное лицо.';
  $('#result').showModal();
}
const win = () => finish(true);
const lose = () => finish(false);

function startGame() {
  state = { heat: 0, suspicion: 0, combo: 1, completed: new Set() };
  selected = 'sticker';
  started = true;
  busy = false;
  $$('.hotspot').forEach(button => button.classList.remove('used'));
  $$('.slot').forEach((slot, index) => slot.classList.toggle('active', index === 0));
  $('#result').close();
  $('#intro').close();
  render();
  clearInterval(routeTimer);
  routeTimer = setInterval(patrol, 4200);
  toast('Рабочий день начался. Следи за маршрутами!');
}

$$('.hotspot').forEach(button => button.addEventListener('click', () => perform(button)));
$$('.slot:not(.empty)').forEach(button => button.addEventListener('click', () => {
  $$('.slot').forEach(slot => slot.classList.remove('active'));
  button.classList.add('active');
  selected = button.dataset.item;
  toast(`Выбрано: ${button.querySelector('small').textContent}`);
}));
$('#innocentBtn').addEventListener('click', innocent);
$('#startBtn').addEventListener('click', startGame);
$('#restartBtn').addEventListener('click', startGame);
$('#closeHelp').addEventListener('click', () => $('#intro').close());
$('#helpBtn').addEventListener('click', () => $('#intro').showModal());
document.addEventListener('keydown', event => {
  if (event.code === 'Space') { event.preventDefault(); innocent(); }
  if ('1234'.includes(event.key)) $$('.slot')[Number(event.key) - 1]?.click();
});
setInterval(() => {
  if (!started) return;
  minute += 1;
  $('#clock').textContent = `13:${String(minute % 60).padStart(2, '0')}`;
}, 5000);
$('#intro').showModal();
