"""Historical B3 draft. User gameplay feedback returned visual acceptance to R3."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
BATCH = PROJECT / '.runtime/visual004_roles_20261104/performance_r2/rendering_path_v1/options_research_20261105'
Q = BATCH / 'visual_r2_20261105'
SESSIONS = BATCH / 'PlaySessions'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    timing = read(ROOT / 'ceiling_timing_review.json')
    roi = read(ROOT / 'advisor_final_rois.json')['data']
    performance_rows = []
    for r in timing['runs']:
        f = r['all_after_reveal']['frame']
        movement = r['coverage']['movement']
        slow = r['all_after_reveal']['slow_streak']['longest_by_duration']
        label = r['id'].removeprefix('R2_')
        performance_rows.append([label, f"{movement['reached']}/{movement['total']}",
            f"{f['average_fps']:.2f}", f"{f['p50_ms']:.3f}", f"{f['p95_ms']:.3f}",
            f"{f['p99_ms']:.3f}", f"{f['max_ms']:.3f}", str(f['over80']),
            f"{slow['frames']}帧 / {slow['ms']:.1f}ms"])
    names = [('大厅/接待室', '01_interior_overview_main.png'),
             ('窗边走廊', '02_window_reflection_main.png'),
             ('会议室/相邻走廊', '03_dark_actor_furniture_main.png')]
    scenes = []
    for name, file in names:
        scenes.append({'name': name,
            'caption': '同机位原始 Camera。中央顶灯覆盖整间房，保留真实倒影及墙体、家具遮挡；A 的强亮斑不再是本轮目标。C7 静态图与最终 B3 使用相同渲染实现，B3 仅补正预算标签。',
            'images': {'A': str(SESSIONS / 'AB20261105_VIS_A' / file),
                       'B0': str(SESSIONS / 'AB20261105_VIS_B' / file),
                       'C': str(SESSIONS / 'R2_C7_rooms36' / file)}})
    contrast_rows = []
    for label, key in [('大厅原亮斑位置', 'hall_lit'), ('大厅原阴面位置', 'hall_shadow'),
                       ('会议室原窗边位置', 'dark_window'), ('会议室原暗地面位置', 'dark_floor')]:
        contrast_rows.append([label] + [f"{roi[k][key]['median']:.2f}" for k in ['A','B0','B3']])
    data = {
        'date': '2026-11-06',
        'summary': '中央顶灯版已交付。按最新要求，每房优先中央布灯、照亮整间，取消强聚焦光斑。以“大部分可见游玩帧不超过80ms”为本轮门槛：完整复测1,989帧，最慢43.775ms，超过80ms为0。',
        'status': [
            {'item': '画面', 'result': '完成15个房间/走廊取景复核；屋顶遮光、摩尔纹抑制、血液/火焰/枪口颜色修复均保留。'},
            {'item': '功能', 'result': '走动、原生Space冲刺、开枪、受击、反复断复电、F4记录、静音启动和退出恢复通过。'},
            {'item': '性能', 'result': '完整三区83点及840战斗步满足本轮80ms门槛；未认证全游戏稳定60 FPS。'},
            {'item': '当前制作状态', 'result': '本轮已结束；旧战斗彩色条带及重复F10重置问题仍未关闭，本轮不自动追加测试。'}],
        'entry': str(PROJECT / 'Run_PERF009_Candidate.cmd'),
        'integration': '沿用原独立小样与原入口；正式游戏未接入本轮渲染改动。',
        'scenes': scenes,
        'contrast': {'headers':['取样区域','A 旧参照','B0 早期修复版','B3 中央顶灯'], 'rows':contrast_rows},
        'performance': {
            'headers':['记录','路线点','平均FPS','P50 ms','P95 ms','P99 ms','最慢ms','>80ms','最长连续>20ms'],
            'rows':performance_rows,
            'conditions':'同一独立工程、同种子、104件家具、原生敌人AI/物理、640×360主视图、320×180逐帧镜像、60帧上限、私有静音。计时不写截图，保留揭幕/阶段切换与失焦帧；取图和录像不作为FPS证据。用户进程未被关闭，后台快照保留。',
            'interpretation':'最终B3为reverse41，三区83/83点和840战斗步完整，1,989个可见帧均不超过43.775ms。after_ceiling40未走完路线、退出1，保留原始失败，不能用于同路收益归因；41补齐覆盖。B2是修好屋顶和颜色但尚未改中央顶灯的中间版。B3阴影成本增加，平均帧率低于B2，本轮按用户新80ms门槛交付。真实AI与后台变化使差值不等于纯渲染收益。'},
        'changes': [
            '15个房间优先中央顶灯，长房/走廊按实际轮廓分段，共20盏；宽覆盖和平缓衰减替代桌边、门边的小光斑。全局环境亮度保持0.18。',
            '顶灯自定义地面高光遵守灯本身的高光设置；地板改为线性叠光，避免旧走廊绑定重新启用导致过亮、条纹的方式。实际平面倒影仍逐帧更新。',
            '补回接待室被误当作电梯井而漏掉的140格遮光顶面；顶面不挡游戏相机，仍阻止外光越顶直照。',
            '环境纹理缩小采样和地面微细颗粒按像素覆盖过滤，保留人物像素轮廓及清晰度。',
            '局部修正血液、火焰和枪口的颜色转换，保留原作者橙色血液及暖色火焰，没有恢复全局调色板。',
            '原入口选择固定的B3候选，启动前核对文件、静音；退出恢复临时源。回执原子写入并有界重试，避免短暂文件读取锁导致交付失败。'],
        'limits': [
            '本轮80ms结论适用于已验证的小样路线与战斗范围，不能外推为任意楼层、任意时长均无长帧。',
            '灯数由25降为20，但室内阴影由15增为20；不能宣称渲染开销未增。完整B3仍有15帧/0.429秒连续超过20ms，此结果符合用户最新80ms门槛。',
            '该完整B3测试的启动遮罩到交还控制约8.64秒；隐藏加载等待与可见游玩帧分开记录。',
            'motion37直接冲刺调用没有启动，原因未证实；两次原入口Space输入检查均实际进入冲刺，该失败记录没有删除。',
            '旧战斗彩色条带与连续F10重置的预热容量问题未完成专项复核；当前新进程启动通过不代表这些历史问题已解决。',
            '范围收紧实验B4已暂存并取图，未计时、未安装；最终交付固定为B3。'],
        'evidence': [
            {'label':'顾问独立性能复算（含失败及旧版长帧）','path':str(ROOT/'ceiling_timing_review.json')},
            {'label':'最终入口与恢复独立审计','path':str(ROOT/'advisor_delivery_audit.json')},
            {'label':'15个房间原始Camera与灯位记录','path':str(SESSIONS/'R2_C7_rooms36/room_coverage.json')},
            {'label':'顶灯改前/改后移动对照（视频速度不是运行帧率）','path':str(Q/'motion_media_ceiling/camera_reception_pair.mp4')},
            {'label':'血液、火焰、枪口与断复电原始记录','path':str(SESSIONS/'R2_B3_functional38/functional.json')},
            {'label':'新版战斗实拍','path':str(SESSIONS/'R2_B3_functional38/functional_0050.png')},
            {'label':'新版断电实拍','path':str(SESSIONS/'R2_B3_functional38/functional_0036.png')},
            {'label':'最终原入口启动、Space冲刺、F4与静音检查','path':str(SESSIONS/'Play_20261106-021254_startup_check/smoke_check.json')},
            {'label':'渲染专项完整交付记录','path':str(Q/'FINAL_B3_REPORT.md')},
            {'label':'本轮最终任务书与最新验收标准','path':str(PROJECT/'docs/plans/rendering-contrast-moire-r2-20261105.md')}],
    }
    (ROOT/'review.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Assembled final B3 review; same entry, user-defined 80ms gate.')


if __name__ == '__main__':
    raise SystemExit('B3 visual delivery was returned for R3 repair; do not publish this completed-status draft.')
