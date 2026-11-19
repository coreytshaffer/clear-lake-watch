// Source-level regression checks, not rendered/browser or screen-reader tests.
// Run: node --test scripts/accessibility-theme.test.mjs
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
const css = readFileSync(new URL('../styles.css', import.meta.url), 'utf8');
const app = readFileSync(new URL('../app.js', import.meta.url), 'utf8');
const rule = selector => {
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = css.match(new RegExp(escaped + '\\s*\\{([^}]+)\\}'));
  assert.ok(match, `Missing CSS rule ${selector}`);
  return Object.fromEntries([...match[1].matchAll(/([\w-]+)\s*:\s*([^;]+);/g)].map(m => [m[1], m[2].trim()]));
};
const light = rule(':root');
const dark = { ...light, ...rule(':root[data-theme="dark"]') };
const resolve = (value, vars) => value.startsWith('var(') ? resolve(vars[value.slice(4,-1)], vars) : value;
const rgb = value => {
  if (value.startsWith('#')) {
    let h = value.slice(1); if (h.length === 3) h = [...h].map(x=>x+x).join('');
    return [0,2,4].map(i=>parseInt(h.slice(i,i+2),16)).concat(1);
  }
  return value.match(/[\d.]+/g).map(Number);
};
const over = (fg,bg) => fg.slice(0,3).map((c,i)=> c*(fg[3]??1)+bg[i]*(1-(fg[3]??1)));
const lum = c => c.slice(0,3).map(v=>v/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((s,v,i)=>s+v*[.2126,.7152,.0722][i],0);
const ratio = (a,b) => (Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05);

test('light review signal text has normal-text AA contrast on a cream panel', () => {
  const badge=rule('.signal-review');
  const background=over(rgb(badge.background),rgb(light['--panel-strong']));
  const contrast=ratio(rgb(resolve(badge.color,light)),background);
  assert.ok(contrast>=4.5, `Review signal contrast ${contrast.toFixed(2)}:1 < 4.5:1`);
});
for (const [theme,vars] of Object.entries({light,dark})) test(`${theme} primary button text has normal-text AA contrast`,()=>{
  const button=rule('.button-primary');
  const contrast=ratio(rgb(resolve(button.color,vars)),rgb(resolve(button.background,vars)));
  assert.ok(contrast>=4.5,`${theme} primary contrast ${contrast.toFixed(2)}:1 < 4.5:1`);
});

test('theme action label describes the next theme without a pressed state; persists and updates browser color',()=>{
  const attrs=new Map([['aria-pressed','false']]);
  const toggle={textContent:'',setAttribute:(k,v)=>attrs.set(k,v),removeAttribute:k=>attrs.delete(k)};
  const colors={light:'#fff',dark:'#000'};
  const stored=new Map(); const meta=new Map();
  const context={document:{documentElement:{dataset:{}}}, themeToggleElement:toggle,
    themeColorMetaElement:{setAttribute:(k,v)=>meta.set(k,v)},themeColors:colors,
    localStorage:{setItem:(k,v)=>stored.set(k,v)},console};
  vm.createContext(context);
  // Execute the production function, isolating unrelated dashboard/data setup.
  const start=app.indexOf('const setTheme ='); const end=app.indexOf('const setupThemeToggle =',start);
  vm.runInContext(app.slice(start,end)+'\nthis.applyTheme = setTheme;',context);
  for(const theme of ['light','dark','light']){
    context.applyTheme(theme);
    assert.equal(context.document.documentElement.dataset.theme,theme);
    assert.equal(stored.get('clearLakeTheme'),theme);
    assert.equal(meta.get('content'),colors[theme]);
    assert.match(toggle.textContent,theme==='dark'?/switch to light mode/i:/switch to dark mode/i);
    assert.equal(attrs.has('aria-pressed'),false);
  }
});
