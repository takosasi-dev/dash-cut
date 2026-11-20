// Web 版の流れをまとめて確かめる(Chrome 1 回の起動で済ませる)。
//   起動の時間・マウスだけで タイトル → プレイ → 結果 → もう1回(AC-18)・矢印とスペースの突進(FR-3)・タッチの払い(AC-19 の代わり)・
//   タブが裏で一時停止(AC-21)・保存が dash-cut/save に残る・コピー(FR-21)・読み込みの後の通信 0 件(AC-22)・コンソールのエラー 0 件
//     node tests/web/check.mjs            手元の build/web を配って確かめる(1 回ぶん遊ぶので 1〜2 分)
//     node tests/web/check.mjs --quick    起動・タイトル・最初の払いまで(古い版の公開 URL にも使える)
//     DC_URL=https://…/dash-cut/ node tests/web/check.mjs
import { DESKTOP, expect, failureCount, open, serve, sleep } from './lib.mjs';
import { playUntil } from './play.mjs';

const quick = process.argv.includes('--quick');
const site = serve();
const page = await open(site.url + '?debug=1', DESKTOP);
try {
	expect(page.booted, `Godot が起動した(${page.bootMs} ms)`);
	const t = await page.waitState((s) => s.screen === 'title', 60000);
	expect(!!t, `タイトルが出る(ページを開いてから ${Date.now() - page.t0} ms)`);
	const loadedAt = Date.now();
	expect(await page.clickButton('daily'), 'マウスで「今日の並び」を押せる');
	const p0 = await page.waitState((s) => s.screen === 'play' && s.play);
	expect(!!p0 && p0.play.time_left === 7200, '今日の並びでプレイ。時計は止まっている');
	await sleep(1100); // 印が明ける
	// 上へ払う: T1 の 3 体が斬れて 900 点(AC-3 を本物のマウスで)
	await page.swipe(360, 900, 0, -120);
	const c1 = await page.waitState((s) => s.play?.points >= 900, 3000);
	expect(!!c1 && c1.play.points === 900, `上へ払って T1 の 3 体: ${c1?.play?.points} 点`);
	expect(!!c1 && c1.sfx > 0, `効果音を鳴らした数 ${c1?.sfx}(消音の Chrome なので耳では聞いていない)`);
	if (!quick) {
		// 矢印とスペース(FR-3): 右を押したままスペース
		await page.waitState((s) => !s.play.dashing && s.play.freeze === 0, 2000);
		const before = await page.state();
		await page.keyDown('ArrowRight');
		await page.key('Space');
		await page.keyUp('ArrowRight');
		const k = await page.waitState((s) => s.play.x > before.play.x + 100, 2000);
		expect(!!k, `→ とスペースで右へ突進(x ${Math.round(before.play.x)} → ${Math.round(k?.play?.x)})`);
		// タッチの払い(1 本目だけ)。タッチから作られたマウスのイベントで 2 回突進しないこと
		await page.waitState((s) => !s.play.dashing && s.play.freeze === 0, 2000);
		await sleep(300);
		const b2 = await page.state();
		await page.cdp.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 2 });
		const [tx, ty] = await page.gameCss(360, 700);
		const [ux, uy] = await page.gameCss(240, 700);
		await page.cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: tx, y: ty, id: 0 }] });
		for (let i = 1; i <= 4; i++) await page.cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: tx + (ux - tx) * i / 4, y: ty, id: 0 }] });
		await page.cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
		await page.cdp.send('Emulation.setTouchEmulationEnabled', { enabled: false });
		const tch = await page.waitState((s) => s.play.x < b2.play.x - 100, 2000);
		await sleep(400);
		const after = await page.state();
		expect(!!tch, `タッチで左へ払って突進(x ${Math.round(b2.play.x)} → ${Math.round(after.play.x)})`);
		expect(b2.play.charges - after.play.charges <= 1 || after.play.points > b2.play.points, `タッチの 1 回で突進は 1 回(回数 ${b2.play.charges} → ${after.play.charges})`);
		// タブが裏に回ると一時停止。戻っても自動では再開しない
		await page.hide();
		await sleep(800);
		await page.show();
		expect(!!(await page.waitState((s) => s.paused, 5000)), 'タブが裏で一時停止');
		const tl = (await page.state()).play.time_left;
		await sleep(1000);
		expect((await page.state()).play.time_left === tl, `戻っても止まったまま(残り ${tl} tick)`);
		await page.key('Escape');
		expect(!!(await page.waitState((s) => !s.paused, 3000)), 'Esc で続ける');
		// 最後まで遊ぶ(マウスだけ)
		const res = await playUntil(page, (s) => s.screen === 'result', { timeoutMs: 150000 });
		expect(!!res, '結果の画面まで行く');
		await sleep(400);
		const saved = await page.saved();
		expect(saved?.daily?.first > 0, `保存が dash-cut/save に入る: ${JSON.stringify(saved)}`);
		await page.evaluate(`navigator.clipboard.writeText('').catch(() => {})`);
		await page.cdp.send('Browser.grantPermissions', { permissions: ['clipboardReadWrite', 'clipboardSanitizedWrite'] }).catch(() => {});
		await page.clickButton('copy');
		await sleep(400);
		const clip = await page.evaluate('navigator.clipboard.readText().catch((e) => "(読めない: " + e + ")")');
		expect(String(clip).startsWith('DashCut '), `コピーのボタン: ${JSON.stringify(clip).slice(0, 70)}`);
		await sleep(300);
		expect(await page.clickButton('retry'), 'マウスで「もう1回」を押せる');
		expect(!!(await page.waitState((s) => s.screen === 'play' && s.play?.time_left === 7200, 3000)), 'もう1回で同じ入口の初めから');
		// 読み込みの後、開き直すまでの通信は 0 件(AC-22。3 分見る)
		await sleep(Math.max(0, loadedAt + 181000 - Date.now()));
		const reloadAt = Date.now();
		const net = page.requests.filter((r) => r.at > loadedAt && r.at < reloadAt);
		expect(net.length === 0, `読み込みの後の通信 ${net.length} 件(${Math.round((reloadAt - loadedAt) / 1000)} 秒見た)` + (net.length ? ': ' + net.map((r) => r.url).join(', ') : ''));
		// 開き直しても記録が残る
		expect(await page.goto(site.url + '?debug=1'), '開き直す');
		await page.waitState((s) => s.screen === 'title', 30000);
		expect((await page.saved())?.daily?.first === saved?.daily?.first, '開き直しても記録が残る');
	}
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).join(' | ').slice(0, 400) : ''));
} finally {
	await page.close();
	site.stop();
}
process.exit(failureCount() ? 1 : 0);
