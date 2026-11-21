// 全部の画面を 5 つの大きさで撮る(UI の作り直しの前後を見比べる用)。Chrome 1 回の起動で、画面ごとに窓の大きさだけ替えて撮る。
//     node tests/web/shots.mjs before     → build/web_shots/before/<画面>_<幅>x<高さ>.png
//     node tests/web/shots.mjs after      → build/web_shots/after/…
//     node tests/web/shots.mjs after --docs   README の 3 枚(720×1280)を docs/ に写す
//     DC_URL=https://…/dash-cut/ node tests/web/shots.mjs pub
// 縦画面のゲームなので、横の 4 つの大きさは縦横を入れ替えて撮る。スマホ(390×844)は「記録だけ」(落ちない・字が読める、を見る)。
// ボタンはマウスで押す(作り直しの前の版でも同じ手順で撮れるように)。
import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { OUT, ROOT, expect, failureCount, open, serve, sleep } from './lib.mjs';
import { playUntil } from './play.mjs';

const PHASE = process.argv[2] && !process.argv[2].startsWith('--') ? process.argv[2] : 'after';
const DIR = path.join(OUT, PHASE);
mkdirSync(DIR, { recursive: true });
const SIZES = [[720, 1280], [1080, 1920], [768, 1024], [1080, 2560], [390, 844]];
const BASE = { width: 720, height: 1280, deviceScaleFactor: 1, mobile: false };
const site = serve();
const page = await open(site.url + '?debug=1', BASE);

async function shootAll(name, settle = 250) {
	for (const [w, h] of SIZES) {
		await page.resize({ width: w, height: h, deviceScaleFactor: 1, mobile: false });
		await sleep(settle);
		const data = (await page.cdp.send('Page.captureScreenshot', { format: 'png' })).data;
		writeFileSync(path.join(DIR, `${name}_${w}x${h}.png`), Buffer.from(data, 'base64'));
	}
	await page.resize(BASE);
	await sleep(150);
}

async function shootOne(name) {
	const data = (await page.cdp.send('Page.captureScreenshot', { format: 'png' })).data;
	writeFileSync(path.join(DIR, `${name}_720x1280.png`), Buffer.from(data, 'base64'));
}

try {
	expect(page.booted, `起動した(${page.bootMs} ms)`);
	expect(!!(await page.waitState((s) => s.screen === 'title', 30000)), 'タイトルが出る');
	console.log(`    タイトルまで: ${Date.now() - page.t0} ms`);
	await sleep(900);
	await shootAll('s1_title_first', 400);
	await page.clickButton('settings');
	await page.waitState((s) => s.screen === 'settings');
	await sleep(600);
	await shootAll('s4_settings');
	await page.clickButton('back');
	await page.waitState((s) => s.screen === 'title');
	await page.clickButton('daily');
	expect(!!(await page.waitState((s) => s.screen === 'play' && s.play)), '今日の並びでプレイへ');
	await sleep(1300); // 印が明ける
	await shootAll('s2_start', 200);
	// 狙い: 上へ払って離さずに撮る(大きさを替えると座標がずれるので 720×1280 だけ)
	await page.swipe(360, 900, 0, -120, { release: false, holdMs: 150 });
	await shootOne('s2_aim');
	await page.release(360, 780);
	for (let k = 0; k < 4; k++) await shootOne(`s2_cut_${k}`);
	let paused = false;
	let mid = false;
	const res = await playUntil(page, (s) => s.screen === 'result', {
		timeoutMs: 150000,
		onState: async (s) => {
			if (s.screen !== 'play' || !s.play) return;
			if (!mid && s.play.chain >= 3 && s.play.enemies >= 5 && !s.play.dashing) {
				mid = true;
				await shootAll('s2_play', 120);
			}
			if (!paused && s.play.time_left < 4000) {
				paused = true;
				await page.key('Escape');
				await page.waitState((t) => t.paused, 3000);
				await sleep(500);
				await shootAll('s5_pause');
				await page.key('Escape');
				await page.waitState((t) => !t.paused, 3000);
			}
		},
	});
	expect(!!res, '結果まで行く');
	await sleep(1500);
	await shootAll('s3_result', 300);
	// 2 回目: 1 回払って手を止め、時間切れの「最高まで」の結果
	await page.clickButton('retry');
	await page.waitState((s) => s.screen === 'play' && s.play);
	await sleep(1300);
	await page.swipe(360, 900, 0, -120);
	await page.waitState((s) => s.play?.clock_running, 3000);
	await page.waitState((s) => s.screen === 'result', 90000);
	await sleep(1500);
	await shootAll('s3_result_second', 300);
	await page.clickButton('title');
	await page.waitState((s) => s.screen === 'title');
	await sleep(900);
	await shootAll('s1_title_record', 400);
	// 新しい記録の結果(練習の最高を 500 点にした保存を置いて開き直し、900 点を取る)
	if (!process.argv.includes('--no-best')) {
		const sv = await page.saved();
		sv.practice_best = 500;
		await page.evaluate(`localStorage.setItem('dash-cut/save', ${JSON.stringify(JSON.stringify(sv))})`);
		await page.goto(page.url0);
		await page.waitState((s) => s.screen === 'title', 30000);
		await sleep(400);
		await page.clickButton('practice');
		await page.waitState((s) => s.screen === 'play' && s.play);
		await sleep(1300);
		await page.swipe(360, 900, 0, -120);
		await page.waitState((s) => s.play?.clock_running, 3000);
		await page.waitState((s) => s.screen === 'result', 90000);
		await sleep(400);
		await shootOne('s3_result_best_stamp');
		await sleep(1100);
		await shootAll('s3_result_best', 300);
	}
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).join(' | ').slice(0, 400) : ''));
	// 読み込み中の画面(index.wasm を止めて、Godot が立ち上がる前の画面のまま撮る)
	await page.cdp.send('Network.setBlockedURLs', { urls: ['*index.wasm*'] });
	await page.cdp.send('Page.navigate', { url: page.url0.split('?')[0] });
	await sleep(2500);
	await shootAll('s0_loading', 200);
	await page.cdp.send('Network.setBlockedURLs', { urls: [] });
	if (process.argv.includes('--docs')) {
		mkdirSync(path.join(ROOT, 'docs'), { recursive: true });
		for (const [from, to] of [['s1_title_record', 'title'], ['s2_cut_1', 'play'], ['s3_result', 'result']]) copyFileSync(path.join(DIR, `${from}_720x1280.png`), path.join(ROOT, 'docs', `${to}.png`));
	}
} finally {
	await page.close();
	site.stop();
}
process.exit(failureCount() ? 1 : 0);
