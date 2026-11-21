// 動きの途中を撮る(止まった画面の shots.mjs では写らない物): 斜めの一太刀の最中・触れたボタン・押している間のボタン・
// 結果の最初の 300 ms・残り 10 秒の赤い時計・点滅を弱める 入 のタイトルと切り替わり・横に余りが出る窓(768×1024・1280×800)の遊び。
//     node tests/web/motion.mjs      → build/web_shots/motion/
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { OUT, expect, failureCount, open, serve, sleep } from './lib.mjs';
import { playUntil } from './play.mjs';

const DIR = path.join(OUT, 'motion');
mkdirSync(DIR, { recursive: true });
const BASE = { width: 720, height: 1280, deviceScaleFactor: 1, mobile: false };
const site = serve();
const page = await open(site.url + '?debug=1', BASE);

async function shoot(name) {
	const data = (await page.cdp.send('Page.captureScreenshot', { format: 'png' })).data;
	writeFileSync(path.join(DIR, `${name}.png`), Buffer.from(data, 'base64'));
}
const mouse = (type, x, y, buttons) => page.cdp.send('Input.dispatchMouseEvent', { type, x, y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1 });
async function buttonCss(name) {
	const s = await page.waitState((st) => st.buttons && st.buttons[name] && !st.moving, 8000);
	if (!s) throw new Error(`${name} が無い: ${JSON.stringify(await page.state()).slice(0, 300)}`);
	return page.gameCss(...s.buttons[name]);
}

try {
	expect(!!(await page.waitState((s) => s.screen === 'title', 30000)), 'タイトルが出る');
	await sleep(900);
	// 触れたボタン(練習)と押している間のボタン
	const [px, py] = await buttonCss('practice');
	await mouse('mouseMoved', px, py, 0);
	await sleep(200);
	await shoot('button_hover');
	await mouse('mousePressed', px, py, 1);
	await sleep(150);
	await shoot('button_pressed');
	await mouse('mouseMoved', 4, py, 1); // ボタンの外(窓の中の左の端)で離して押さずに済ませる
	await mouse('mouseReleased', 4, py, 0);
	await sleep(300);
	// 斜めの一太刀の最中: タイトル → 設定 → 戻る を繰り返し、押してからの待ちを変えて 1 枚ずつ
	for (const [i, ms] of [[0, 20], [1, 80], [2, 140], [3, 200]]) {
		const [sx, sy] = await buttonCss('settings');
		await page.click(sx, sy);
		await sleep(ms);
		const s = await page.state();
		await shoot(`wipe_${i}_${ms}ms${s.moving ? '' : '_done'}`);
		await page.waitState((st) => st.screen === 'settings' && !st.moving, 3000);
		await page.clickButton('back');
		await page.waitState((st) => st.screen === 'title' && !st.moving, 3000);
	}
	// 今日の並び: 1 回払って時計を動かし、横に余りが出る窓の遊び・残り 10 秒の赤い時計・結果の最初の 300 ms
	await page.clickButton('daily');
	await page.waitState((s) => s.screen === 'play' && s.play);
	await sleep(1300);
	await page.swipe(360, 900, 0, -120);
	await page.waitState((s) => s.play?.clock, 3000);
	await sleep(300);
	for (const [w, h] of [[768, 1024], [1280, 800]]) {
		await page.resize({ width: w, height: h, deviceScaleFactor: 1, mobile: false });
		await sleep(250);
		await shoot(`play_${w}x${h}`);
	}
	await page.resize(BASE);
	// 立ったままだと体力が切れるので、bot で斬り続けて時間切れまで行く(残り 9 秒で 1 枚)
	let red = false;
	const end = await playUntil(page, (s) => s.screen === 'result', {
		timeoutMs: 150000,
		onState: async (s) => {
			if (!red && s.play && s.play.clock && s.play.time_left < 9 * 120) {
				red = true;
				await shoot('clock_red');
			}
		},
	});
	expect(red, '残り 9 秒の時計を撮った');
	expect(!!end, '結果');
	const t0 = Date.now();
	await shoot(`result_first_a_${Date.now() - t0}ms`);
	await shoot(`result_first_b_${Date.now() - t0}ms`);
	await sleep(Math.max(0, 200 - (Date.now() - t0)));
	await shoot(`result_first_c_${Date.now() - t0}ms`);
	// 点滅を弱める 入: タイトルとその切り替わり
	await sleep(600);
	await page.clickButton('title');
	await page.waitState((s) => s.screen === 'title' && !s.moving, 3000);
	await page.clickButton('settings');
	await page.waitState((s) => s.screen === 'settings' && !s.moving, 3000);
	await page.clickButton('reduce_flash_on');
	await sleep(200);
	await shoot('settings_reduce_on');
	await page.clickButton('back');
	await sleep(60);
	await shoot('reduce_title_fade_60ms');
	await page.waitState((s) => s.screen === 'title' && !s.moving, 3000);
	await sleep(1500);
	await shoot('reduce_title');
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).join(' | ').slice(0, 400) : ''));
} finally {
	await page.close();
	site.stop();
}
process.exit(failureCount() ? 1 : 0);
