// 全部の画面を撮る(build/web_shots/)。--docs を付けると README 用の 3 枚を docs/ に写す。
//     node tests/web/shots.mjs [--docs]
//     DC_URL=https://…/dash-cut/ node tests/web/shots.mjs   公開した物を撮る
// 縦 540×960 で開き、タイトル → 設定 → プレイ(始め・狙い・割れる瞬間・中盤・山場)→ 一時停止 → 結果 の順に撮る。最後に横長の画面でタイトルを 1 枚。
import { copyFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { DESKTOP, OUT, PORTRAIT, ROOT, expect, failureCount, open, serve, sleep } from './lib.mjs';
import { playUntil } from './play.mjs';

const site = serve();
const page = await open(site.url + '?debug=1', PORTRAIT);
const docs = process.argv.includes('--docs');
try {
	expect(page.booted, `起動した(${page.bootMs} ms)`);
	expect(!!(await page.waitState((s) => s.screen === 'title', 30000)), 'タイトルが出る');
	console.log(`    タイトルまで: ${Date.now() - page.t0} ms`);
	await sleep(500);
	await page.shot('s1_title');
	await page.clickButton('settings');
	await page.waitState((s) => s.screen === 'settings');
	await sleep(200);
	await page.shot('s4_settings');
	await page.clickButton('back');
	await page.waitState((s) => s.screen === 'title');
	await page.clickButton('daily');
	const p0 = await page.waitState((s) => s.screen === 'play' && s.play);
	expect(!!p0, '今日の並びでプレイへ');
	await sleep(1100); // 印が明ける
	await page.shot('s2_play_start');
	// 狙い: 上へ払って離さずに撮る
	await page.swipe(360, 900, 0, -120, { release: false, holdMs: 150 });
	await page.shot('s2_play_aim');
	await page.release(360, 780);
	// 割れる瞬間を続けて撮る
	for (let k = 0; k < 6; k++) await page.shot(`s2_cut_${k}`);
	const mid = { taken: new Set() };
	const want = {
		s2_play_chain: (s) => s.play.chain >= 4 && s.play.enemies >= 5,
		s2_play_mid: (s) => s.play.foes.some((f) => f[2] === 1 && f[3] === 0) && s.play.enemies >= 6,
		s2_play_late: (s) => s.play.foes.some((f) => f[2] === 2 && f[3] === 0) && s.play.enemies >= 5,
		s2_over: (s) => s.play.time_left === 0 || s.play.hp === 0,
	};
	let hp = 3;
	let paused = false;
	const res = await playUntil(page, (s) => s.screen === 'result', {
		timeoutMs: 150000,
		onState: async (s) => {
			if (s.screen !== 'play' || !s.play) return;
			if (s.play.hp < hp && !mid.taken.has('s2_hurt')) { await page.shot('s2_hurt'); mid.taken.add('s2_hurt'); }
			hp = s.play.hp;
			for (const [label, when] of Object.entries(want)) {
				if (!mid.taken.has(label) && when(s)) { await page.shot(label); mid.taken.add(label); }
			}
			if (!paused && s.play.time_left < 4000) {
				paused = true;
				await page.key('Escape');
				await page.waitState((t) => t.paused, 3000);
				await sleep(200);
				await page.shot('s5_pause');
				await page.key('Escape');
				await page.waitState((t) => !t.paused, 3000);
			}
		},
	});
	expect(!!res, `結果まで行く(撮った: ${[...mid.taken].join(' ')})`);
	await sleep(900);
	await page.shot('s3_result');
	await page.resize(DESKTOP);
	await page.clickButton('title');
	await page.waitState((s) => s.screen === 'title');
	await sleep(400);
	await page.shot('s1_title_desktop');
	await page.clickButton('practice');
	await page.waitState((s) => s.screen === 'play' && s.play);
	await sleep(1100);
	await page.swipe(360, 900, 0, -120, { release: false, holdMs: 150 });
	await page.shot('s2_play_desktop');
	await page.release(360, 780);
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).join(' | ').slice(0, 400) : ''));
	if (docs) {
		mkdirSync(path.join(ROOT, 'docs'), { recursive: true });
		for (const [from, to] of [['s1_title', 'title'], ['s2_cut_2', 'play'], ['s3_result', 'result']]) copyFileSync(path.join(OUT, `${from}.png`), path.join(ROOT, 'docs', `${to}.png`));
	}
} finally {
	await page.close();
	site.stop();
}
process.exit(failureCount() ? 1 : 0);
