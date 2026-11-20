// ブラウザの中で遊ぶ bot(本物のマウスで払う)。window.dcState の敵の位置から、320 px の線で一番多く斬れる向きを選ぶ。
// 状態の窓口は読むだけで、判定は core のまま(線の数え方は core/geom の考えを写した目安)。
import { sleep } from './lib.mjs';

const DASH = 320;
const BLADE = 14;
const R = [18, 16, 20];

function segDist(ax, ay, bx, by, px, py) {
	const dx = bx - ax, dy = by - ay;
	const l2 = dx * dx + dy * dy;
	let t = l2 > 0 ? ((px - ax) * dx + (py - ay) * dy) / l2 : 0;
	t = Math.max(0, Math.min(1, t));
	return Math.hypot(ax + dx * t - px, ay + dy * t - py);
}

// 一番多く斬れる向き [dx, dy, n]。敵がいなければ null
export function bestDash(p) {
	const foes = (p.foes || []).filter((f) => f[3] === 0);
	let best = null;
	for (const f of foes) {
		const d = Math.hypot(f[0] - p.x, f[1] - p.y) || 1;
		const ux = (f[0] - p.x) / d, uy = (f[1] - p.y) / d;
		const ex = Math.max(14, Math.min(706, p.x + ux * DASH)), ey = Math.max(214, Math.min(1146, p.y + uy * DASH));
		const n = foes.filter((g) => segDist(p.x, p.y, ex, ey, g[0], g[1]) <= R[g[2]] + BLADE).length;
		if (!best || n > best[2]) best = [ux, uy, n];
	}
	return best;
}

// 1 回払う。払える状態でなければ false
export async function dashOnce(page, s) {
	const p = s.play;
	if (!p || p.dashing || p.freeze > 0 || s.paused) return false;
	const b = bestDash(p);
	if (!b) return false;
	await page.swipe(360, 640, Math.round(b[0] * 120), Math.round(b[1] * 120));
	return true;
}

// until(s) が真になるまで遊ぶ。onState(s) は毎回呼ぶ(撮る時に使う)
export async function playUntil(page, until, { onState = async () => {}, gapMs = 220, timeoutMs = 120000 } = {}) {
	const end = Date.now() + timeoutMs;
	while (Date.now() < end) {
		const s = await page.state();
		if (until(s)) return s;
		await onState(s);
		if (s.screen === 'play' && await dashOnce(page, s)) await sleep(gapMs);
		else await sleep(40);
	}
	return null;
}
