export const MAX_SUSPICION = 100;

export function applyPrank(state, action) {
  if (state.completed.has(action.task)) return state;
  const completed = new Set(state.completed).add(action.task);
  const combo = Math.min(4, completed.size + 1);
  return {
    ...state,
    completed,
    combo,
    heat: Math.min(100, state.heat + Math.round(action.heat * combo / 2)),
    suspicion: Math.min(MAX_SUSPICION, state.suspicion + action.suspicion),
  };
}

export function calmDown(state, amount = 22) {
  return { ...state, suspicion: Math.max(0, state.suspicion - amount) };
}

export function rankFor(heat) {
  if (heat >= 90) return 'Легенда опенспейса';
  if (heat >= 70) return 'Бедствие отдела';
  if (heat >= 45) return 'Серый кардинал';
  if (heat >= 20) return 'Офисный шутник';
  return 'Стажёр';
}
