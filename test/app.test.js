import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import { applyPrank, calmDown, rankFor } from '../src/game-core.js';
test('game shell exposes the core mechanics',()=>{const html=fs.readFileSync('index.html','utf8');for(const text of ['НАКАЛ ОТДЕЛА','ПАЛЕВО','КОМБО','НЕВИННОЕ ЛИЦО','Ошибка печати'])assert.match(html,new RegExp(text))});
test('all prank actions have gameplay data',()=>{const js=fs.readFileSync('src/main.js','utf8');for(const action of ['screen','folders','coffee','printer'])assert.match(js,new RegExp(`${action}: \\{ task:`))});
test('scoring creates combos without mutating completed set',()=>{const initial={heat:0,suspicion:0,combo:1,completed:new Set()};const next=applyPrank(initial,{task:'coffee',heat:28,suspicion:15});assert.equal(next.heat,28);assert.equal(next.combo,2);assert.equal(initial.completed.size,0)});
test('innocent face and ranks obey boundaries',()=>{assert.equal(calmDown({suspicion:10}).suspicion,0);assert.equal(rankFor(95),'Легенда опенспейса');assert.equal(rankFor(46),'Серый кардинал')});
