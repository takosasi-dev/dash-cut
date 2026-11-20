// ブラウザでの確かめの土台(RootCall の tests/web/lib.mjs を写して縮めた物)。Web 書き出しを手元で配り、
// 窓なし・消音・使い捨てのプロフィールの Chrome を CDP で動かす。状態は ?debug=1 の時の window.dcState を読むだけで、入力は本物のマウスとキーを送る。
// ポートは HTTP 8811・CDP 9811(DC_HTTP_PORT・DC_CDP_PORT で変えられる)。DC_URL を入れると公開した物を確かめる。
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
export const WEB = path.join(ROOT, 'build', 'web');
export const OUT = path.join(ROOT, 'build', 'web_shots');
export const SAVE_KEY = 'dash-cut/save'; // save/save_store.gd の WEB_KEY
const HTTP_PORT = Number(process.env.DC_HTTP_PORT || 8811);
const CDP_PORT = Number(process.env.DC_CDP_PORT || 9811);
const BOOT_TIMEOUT_MS = 90000;
export const CHROME = process.env.DC_CHROME || path.join(process.env.PROGRAMFILES || '', 'Google', 'Chrome', 'Application', 'chrome.exe');
export const DESKTOP = { width: 1280, height: 800, deviceScaleFactor: 1, mobile: false };
export const PORTRAIT = { width: 540, height: 960, deviceScaleFactor: 1, mobile: false }; // README 用(縦 9:16)
export const GAME_W = 720;
export const GAME_H = 1280;

const KEYS = {
	Enter: { key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13, text: '\r' },
	Escape: { key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 },
	Space: { key: ' ', code: 'Space', windowsVirtualKeyCode: 32, text: ' ' },
	ArrowLeft: { key: 'ArrowLeft', code: 'ArrowLeft', windowsVirtualKeyCode: 37 },
	ArrowUp: { key: 'ArrowUp', code: 'ArrowUp', windowsVirtualKeyCode: 38 },
	ArrowRight: { key: 'ArrowRight', code: 'ArrowRight', windowsVirtualKeyCode: 39 },
	ArrowDown: { key: 'ArrowDown', code: 'ArrowDown', windowsVirtualKeyCode: 40 },
	r: { key: 'r', code: 'KeyR', windowsVirtualKeyCode: 82, text: 'r' },
};

let failures = 0;
export function expect(ok, label) {
	console.log(`${ok ? 'OK' : 'NG'}  ${label}`);
	if (!ok) failures++;
	return ok;
}
export const failureCount = () => failures;
export { sleep };

export async function waitFor(fn, timeoutMs, everyMs = 200) {
	const end = Date.now() + timeoutMs;
	while (Date.now() < end) {
		const v = await fn();
		if (v) return v;
		await sleep(everyMs);
	}
	return null;
}

async function connect(url) {
	const ws = new WebSocket(url);
	await new Promise((ok, ng) => { ws.onopen = ok; ws.onerror = ng; });
	let id = 0;
	const pending = new Map();
	const listeners = [];
	ws.onmessage = (m) => {
		const msg = JSON.parse(m.data);
		if (msg.id && pending.has(msg.id)) {
			const { ok, ng } = pending.get(msg.id);
			pending.delete(msg.id);
			msg.error ? ng(new Error(msg.error.message)) : ok(msg.result);
		} else listeners.forEach((f) => f(msg));
	};
	return {
		send: (method, params = {}) => new Promise((ok, ng) => {
			const i = ++id;
			pending.set(i, { ok, ng });
			ws.send(JSON.stringify({ id: i, method, params }));
		}),
		onEvent: (f) => listeners.push(f),
		close: () => ws.close(),
	};
}

// build/web を /dash-cut/ の下に置いて配る(Pages と同じ形)。
export function serve() {
	if (process.env.DC_URL) return { url: process.env.DC_URL, stop: () => {} };
	if (!existsSync(path.join(WEB, 'index.html'))) throw new Error('build/web/index.html が無い(先に python tools/gd.py export)');
	const root = mkdtempSync(path.join(tmpdir(), 'dc-site-'));
	symlinkSync(WEB, path.join(root, 'dash-cut'), 'junction');
	const py = process.env.DC_PYTHON || 'python';
	const server = spawn(py, ['-m', 'http.server', String(HTTP_PORT), '--bind', '127.0.0.1', '--directory', root], { stdio: 'ignore' });
	return {
		url: `http://127.0.0.1:${HTTP_PORT}/dash-cut/`,
		stop: () => { server.kill(); rmSync(path.join(root, 'dash-cut'), { force: true }); rmSync(root, { recursive: true, force: true }); },
	};
}

export async function open(url, metrics = DESKTOP) {
	if (!existsSync(CHROME)) throw new Error('Chrome が無い');
	mkdirSync(OUT, { recursive: true });
	const profile = mkdtempSync(path.join(tmpdir(), 'dc-chrome-'));
	const args = ['--headless=new', '--mute-audio', `--remote-debugging-port=${CDP_PORT}`, `--user-data-dir=${profile}`,
		'--no-first-run', '--no-default-browser-check', '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
		'--enable-unsafe-swiftshader', 'about:blank'];
	const proc = spawn(CHROME, args, { stdio: 'ignore' });
	const target = await waitFor(async () => {
		try { return (await (await fetch(`http://127.0.0.1:${CDP_PORT}/json/list`)).json()).find((t) => t.type === 'page'); }
		catch { return null; }
	}, BOOT_TIMEOUT_MS);
	if (!target) { proc.kill(); throw new Error('ブラウザにつながらない'); }
	const cdp = await connect(target.webSocketDebuggerUrl);
	const logs = [];
	const requests = [];
	cdp.onEvent((msg) => {
		const p = msg.params;
		if (msg.method === 'Runtime.consoleAPICalled') logs.push({ at: Date.now(), level: p.type, text: p.args.map((a) => a.value ?? a.description).join(' ') });
		else if (msg.method === 'Runtime.exceptionThrown') logs.push({ at: Date.now(), level: 'exception', text: p.exceptionDetails.exception?.description ?? p.exceptionDetails.text });
		else if (msg.method === 'Network.requestWillBeSent' && /^https?:/.test(p.request.url)) requests.push({ at: Date.now(), url: p.request.url });
	});
	for (const m of ['Runtime.enable', 'Page.enable', 'Network.enable']) await cdp.send(m);
	await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
	await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: true });
	await cdp.send('Emulation.setDeviceMetricsOverride', metrics);
	const t0 = Date.now();
	await cdp.send('Page.navigate', { url });
	const booted = await waitFor(() => logs.some((l) => String(l.text).startsWith('Godot Engine v')), BOOT_TIMEOUT_MS, 50);
	const evaluate = async (expression) => (await cdp.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true })).result.value;
	const mouse = (type, x, y, buttons) => cdp.send('Input.dispatchMouseEvent', { type, x, y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1 });
	const page = {
		cdp, logs, requests, booted: booted !== null, bootMs: Date.now() - t0, t0, url0: url,
		evaluate,
		state: async () => { try { return JSON.parse(await evaluate('window.dcState') || '{}'); } catch { return {}; } },
		waitState: async (pred, timeoutMs = 15000) => waitFor(async () => { const s = await page.state(); return pred(s) ? s : null; }, timeoutMs, 30),
		saved: async () => JSON.parse(await evaluate(`localStorage.getItem('${SAVE_KEY}')`) ?? 'null'),
		goto: async (to) => {
			const from = logs.length;
			await cdp.send('Page.navigate', { url: to });
			return await waitFor(() => logs.slice(from).some((l) => String(l.text).startsWith('Godot Engine v')), BOOT_TIMEOUT_MS, 50) !== null;
		},
		resize: (m) => cdp.send('Emulation.setDeviceMetricsOverride', m),
		key: async (k) => {
			const ev = KEYS[k];
			await cdp.send('Input.dispatchKeyEvent', { type: ev.text ? 'keyDown' : 'rawKeyDown', ...ev });
			await cdp.send('Input.dispatchKeyEvent', { type: 'keyUp', ...ev, text: undefined });
		},
		keyDown: (k) => cdp.send('Input.dispatchKeyEvent', { type: KEYS[k].text ? 'keyDown' : 'rawKeyDown', ...KEYS[k] }),
		keyUp: (k) => cdp.send('Input.dispatchKeyEvent', { type: 'keyUp', ...KEYS[k], text: undefined }),
		// ゲームの座標(720×1280 の縦)→ CSS の px(縦横比を保って中央に置かれる)
		gameCss: async (gx, gy) => {
			const [w, h] = await evaluate('[window.innerWidth, window.innerHeight]');
			const k = Math.min(w / GAME_W, h / GAME_H);
			return [(w - GAME_W * k) / 2 + gx * k, (h - GAME_H * k) / 2 + gy * k];
		},
		click: async (x, y) => {
			await mouse('mouseMoved', x, y, 0);
			await mouse('mousePressed', x, y, 1);
			await mouse('mouseReleased', x, y, 0);
		},
		clickButton: async (name) => {
			const s = await page.waitState((st) => st.buttons && st.buttons[name], 8000);
			if (!s) return false;
			await page.click(...(await page.gameCss(...s.buttons[name])));
			return true;
		},
		// 払う(ゲームの座標で始点と差)。steps 回に分けて動かす。holdMs は離す前に待つ時間(狙いの線を撮る時に使う)
		swipe: async (gx, gy, dx, dy, { steps = 4, holdMs = 0, release = true } = {}) => {
			const [x0, y0] = await page.gameCss(gx, gy);
			const [x1, y1] = await page.gameCss(gx + dx, gy + dy);
			await mouse('mouseMoved', x0, y0, 0);
			await mouse('mousePressed', x0, y0, 1);
			for (let i = 1; i <= steps; i++) await mouse('mouseMoved', x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps, 1);
			if (holdMs) await sleep(holdMs);
			if (release) await mouse('mouseReleased', x1, y1, 0);
		},
		release: async (gx, gy) => mouse('mouseReleased', ...(await page.gameCss(gx, gy)), 0),
		hide: async () => {
			await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: false });
			await fetch(`http://127.0.0.1:${CDP_PORT}/json/new?about:blank`, { method: 'PUT' });
		},
		show: () => fetch(`http://127.0.0.1:${CDP_PORT}/json/activate/${target.id}`, { method: 'PUT' }),
		shot: async (label) => {
			const file = path.join(OUT, `${label}.png`);
			writeFileSync(file, Buffer.from((await cdp.send('Page.captureScreenshot', { format: 'png' })).data, 'base64'));
			return file;
		},
		errors: () => logs.filter((l) => ['error', 'exception'].includes(l.level) && !String(l.text).includes('favicon.ico')),
		close: async () => {
			try { await cdp.send('Browser.close'); } catch { /* もう閉じた */ }
			cdp.close();
			await Promise.race([new Promise((ok) => proc.once('exit', ok)), sleep(3000)]);
			proc.kill();
			rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 500 });
		},
	};
	return page;
}
