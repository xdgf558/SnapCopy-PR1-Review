import { corsHeaders } from "../lib/cors";

export function handleAdminPage(): Response {
  return new Response(adminHtml, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      ...corsHeaders()
    }
  });
}

const adminHtml = String.raw`<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SnapCopy Admin</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #fff7f8;
      --panel: rgba(255, 255, 255, 0.78);
      --panel-strong: rgba(255, 255, 255, 0.95);
      --ink: #2e2430;
      --muted: #7d707e;
      --line: rgba(183, 76, 112, 0.18);
      --accent: #b64b70;
      --accent-2: #e27572;
      --good: #1f8a5b;
      --warn: #c98322;
      --bad: #b33f55;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", Arial, sans-serif;
    }

    * { box-sizing: border-box; }
    body {
      margin: 0;
      color: var(--ink);
      background:
        radial-gradient(circle at 20% 0%, rgba(255, 214, 225, 0.9), transparent 32rem),
        radial-gradient(circle at 95% 8%, rgba(250, 223, 206, 0.75), transparent 26rem),
        linear-gradient(180deg, #fff8f9 0%, #fffdf9 100%);
      min-height: 100vh;
    }

    header {
      padding: 38px clamp(20px, 5vw, 68px) 20px;
      display: flex;
      gap: 20px;
      align-items: flex-start;
      justify-content: space-between;
    }

    h1 {
      margin: 0;
      font-size: clamp(34px, 5vw, 58px);
      letter-spacing: 0;
      line-height: 1;
      font-weight: 800;
    }

    .subtitle { margin: 12px 0 0; color: var(--muted); font-size: 17px; }
    .shell { width: min(1180px, calc(100vw - 32px)); margin: 0 auto 48px; }

    .toolbar, .panel {
      border: 1px solid rgba(255, 255, 255, 0.7);
      background: var(--panel);
      box-shadow: 0 24px 70px rgba(160, 79, 107, 0.14), inset 0 1px 0 rgba(255,255,255,0.8);
      backdrop-filter: blur(22px);
      border-radius: 28px;
    }

    .toolbar {
      padding: 18px;
      display: grid;
      grid-template-columns: minmax(220px, 1fr) auto auto auto;
      gap: 12px;
      align-items: center;
      margin-bottom: 18px;
    }

    input, select, button, a.button {
      min-height: 44px;
      border-radius: 999px;
      border: 1px solid var(--line);
      background: rgba(255, 255, 255, 0.72);
      color: var(--ink);
      padding: 0 16px;
      font: inherit;
    }

    input { width: 100%; }
    button, a.button {
      cursor: pointer;
      font-weight: 700;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
    }

    button.primary {
      color: white;
      border: none;
      background: linear-gradient(135deg, var(--accent), var(--accent-2));
      box-shadow: 0 14px 24px rgba(182, 75, 112, 0.24);
    }

    button.ghost { color: var(--accent); }
    button.good { color: var(--good); }
    button.bad { color: var(--bad); }
    button:disabled { opacity: 0.45; cursor: not-allowed; }

    .grid {
      display: grid;
      grid-template-columns: 1.05fr 1.55fr;
      gap: 18px;
      align-items: start;
    }

    .panel { padding: 22px; }
    .panel h2 {
      margin: 0 0 14px;
      font-size: 21px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }

    .badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-width: 28px;
      height: 28px;
      border-radius: 999px;
      background: rgba(182, 75, 112, 0.12);
      color: var(--accent);
      font-size: 14px;
      padding: 0 9px;
      font-weight: 800;
    }

    .badge.hot { background: var(--accent); color: white; }
    .metrics { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; }
    .metric {
      padding: 16px;
      border-radius: 20px;
      background: rgba(255,255,255,0.62);
      border: 1px solid var(--line);
    }
    .metric strong { display: block; font-size: 28px; line-height: 1; }
    .metric span { color: var(--muted); display: block; margin-top: 8px; }

    .settings-row {
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 10px;
      align-items: end;
      margin-top: 14px;
      padding: 14px;
      border-radius: 20px;
      background: rgba(255,255,255,0.58);
      border: 1px solid var(--line);
    }
    .settings-row label { display: grid; gap: 8px; color: var(--muted); }
    .settings-row input { background: rgba(255,255,255,0.82); }
    .toggle-row { align-items: center; }
    .toggle-label { display: flex !important; align-items: center; gap: 12px; color: var(--ink) !important; }
    .toggle-label input {
      width: 22px;
      min-height: 22px;
      accent-color: var(--accent);
    }
    .settings-help { grid-column: 1 / -1; color: var(--muted); font-size: 14px; line-height: 1.45; }

    .notice {
      margin: 14px 0 0;
      padding: 14px 16px;
      border-radius: 18px;
      background: rgba(255, 246, 229, 0.8);
      border: 1px solid rgba(201, 131, 34, 0.24);
      color: #765321;
    }

    .list { display: grid; gap: 12px; }
    .item {
      border-radius: 20px;
      background: var(--panel-strong);
      border: 1px solid var(--line);
      padding: 16px;
    }
    .item-head {
      display: flex;
      gap: 12px;
      justify-content: space-between;
      align-items: flex-start;
    }
    .item-title { font-weight: 800; }
    .item-meta, .muted { color: var(--muted); }
    .item-meta { margin-top: 6px; font-size: 14px; line-height: 1.45; }
    .item-actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 12px; }
    .caption-preview {
      margin-top: 10px;
      padding: 12px;
      border-radius: 14px;
      background: rgba(255, 247, 249, 0.8);
      line-height: 1.55;
      white-space: pre-wrap;
    }

    .filters { display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 14px; }
    .review-actions {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 14px;
      padding: 12px;
      border-radius: 20px;
      background: rgba(255,255,255,0.52);
      border: 1px solid var(--line);
    }
    .action-group { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
    .select-all-label {
      display: inline-flex;
      gap: 8px;
      align-items: center;
      color: var(--muted);
      font-weight: 700;
    }
    .select-all-label input, .sample-select input {
      width: 18px;
      min-height: 18px;
      accent-color: var(--accent);
    }
    .sample-select {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 30px;
      height: 30px;
      border-radius: 999px;
      background: rgba(182, 75, 112, 0.08);
      flex: 0 0 auto;
    }
    .item.selected { border-color: rgba(182, 75, 112, 0.46); box-shadow: inset 0 0 0 1px rgba(182, 75, 112, 0.18); }
    .empty { color: var(--muted); padding: 18px 4px; }
    .toast {
      position: fixed;
      left: 50%;
      bottom: 24px;
      transform: translateX(-50%);
      padding: 12px 18px;
      border-radius: 999px;
      background: rgba(46, 36, 48, 0.88);
      color: white;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.2s ease, transform 0.2s ease;
    }
    .toast.show { opacity: 1; transform: translateX(-50%) translateY(-4px); }

    @media (max-width: 860px) {
      header { flex-direction: column; }
      .toolbar { grid-template-columns: 1fr; }
      .grid { grid-template-columns: 1fr; }
      .metrics { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <header>
    <div>
      <h1>SnapCopy Admin</h1>
      <p class="subtitle">训练数据、样本审核和场景到量提醒。</p>
    </div>
  </header>

  <main class="shell">
    <section class="toolbar">
      <input id="tokenInput" type="password" autocomplete="off" placeholder="输入管理 Token">
      <button id="saveTokenButton" class="primary">保存 Token</button>
      <button id="refreshButton" class="ghost">刷新</button>
      <button id="runCheckButton" class="ghost">触发检查</button>
    </section>

    <section class="grid">
      <div class="panel">
        <h2>今日概览 <span id="alertBadge" class="badge">0</span></h2>
        <div class="metrics">
          <div class="metric"><strong id="pendingCount">0</strong><span>待审核样本</span></div>
          <div class="metric"><strong id="approvedCount">0</strong><span>已通过样本</span></div>
          <div class="metric"><strong id="rejectedCount">0</strong><span>已拒绝样本</span></div>
          <div class="metric"><strong id="usedCount">0</strong><span>已用于训练</span></div>
        </div>
        <div class="settings-row">
          <label>
            训练提醒阈值
            <input id="thresholdInput" type="number" min="10" max="10000" step="1" placeholder="300">
          </label>
          <button id="saveThresholdButton" class="ghost">保存阈值</button>
          <div id="thresholdHelp" class="settings-help">达到这个数量的 approved 样本后，后台会生成训练提醒。</div>
        </div>
        <div class="settings-row toggle-row">
          <label class="toggle-label">
            <input id="cloudEnhancementToggle" type="checkbox">
            云端增强总开关
          </label>
          <button id="saveCloudEnhancementButton" class="ghost">保存开关</button>
          <div id="cloudEnhancementHelp" class="settings-help">关闭后，云端增强 API 会立即返回 503，App 会保留本地文案。</div>
        </div>
        <div id="notice" class="notice" hidden></div>
      </div>

      <div class="panel">
        <h2>训练提醒 <span id="openAlertCount" class="badge">0</span></h2>
        <div id="alerts" class="list"></div>
      </div>
    </section>

    <section class="panel" style="margin-top:18px">
      <h2>样本审核</h2>
      <div class="filters">
        <select id="statusFilter">
          <option value="pending">待审核</option>
          <option value="approved">已通过</option>
          <option value="rejected">已拒绝</option>
          <option value="used_in_training">已用于训练</option>
        </select>
        <select id="kindFilter">
          <option value="">全部类型</option>
          <option value="photo">图片</option>
          <option value="caption">文案</option>
        </select>
        <input id="sceneFilter" placeholder="场景，例如 pet，可留空">
      </div>
      <div class="review-actions">
        <label class="select-all-label">
          <input id="selectAllSamples" type="checkbox">
          全选本页 <span id="selectedCount">0</span>/<span id="visibleCount">0</span>
        </label>
        <div class="action-group">
          <button id="bulkApproveButton" class="good">批量通过</button>
          <button id="bulkRejectButton" class="bad">批量拒绝</button>
          <button id="bulkUsedButton" class="ghost">批量标记已训练</button>
        </div>
        <div class="action-group">
          <button id="exportCsvButton" class="ghost">导出 CSV</button>
          <button id="exportJsonButton" class="ghost">导出 JSON</button>
        </div>
      </div>
      <div id="samples" class="list"></div>
    </section>
  </main>

  <div id="toast" class="toast"></div>

  <script>
    const state = {
      token: localStorage.getItem("snapcopyAdminToken") || "",
      lastOpenAlertCount: Number(localStorage.getItem("snapcopyLastOpenAlertCount") || "0"),
      visibleSampleIds: [],
      selectedSampleIds: new Set()
    };

    const tokenInput = document.getElementById("tokenInput");
    const saveTokenButton = document.getElementById("saveTokenButton");
    const refreshButton = document.getElementById("refreshButton");
    const runCheckButton = document.getElementById("runCheckButton");
    const thresholdInput = document.getElementById("thresholdInput");
    const saveThresholdButton = document.getElementById("saveThresholdButton");
    const cloudEnhancementToggle = document.getElementById("cloudEnhancementToggle");
    const saveCloudEnhancementButton = document.getElementById("saveCloudEnhancementButton");
    const selectAllSamples = document.getElementById("selectAllSamples");
    const bulkApproveButton = document.getElementById("bulkApproveButton");
    const bulkRejectButton = document.getElementById("bulkRejectButton");
    const bulkUsedButton = document.getElementById("bulkUsedButton");
    const exportCsvButton = document.getElementById("exportCsvButton");
    const exportJsonButton = document.getElementById("exportJsonButton");
    const statusFilter = document.getElementById("statusFilter");
    const kindFilter = document.getElementById("kindFilter");
    const sceneFilter = document.getElementById("sceneFilter");

    tokenInput.value = state.token;

    saveTokenButton.addEventListener("click", () => {
      state.token = tokenInput.value.trim();
      localStorage.setItem("snapcopyAdminToken", state.token);
      toast("Token 已保存");
      loadAll();
    });
    refreshButton.addEventListener("click", loadAll);
    runCheckButton.addEventListener("click", runReadinessCheck);
    saveThresholdButton.addEventListener("click", saveThreshold);
    saveCloudEnhancementButton.addEventListener("click", saveCloudEnhancementToggle);
    selectAllSamples.addEventListener("change", toggleSelectAllSamples);
    bulkApproveButton.addEventListener("click", () => reviewSelectedSamples("approved"));
    bulkRejectButton.addEventListener("click", () => reviewSelectedSamples("rejected"));
    bulkUsedButton.addEventListener("click", () => reviewSelectedSamples("used_in_training"));
    exportCsvButton.addEventListener("click", () => downloadExport("csv"));
    exportJsonButton.addEventListener("click", () => downloadExport("json"));
    statusFilter.addEventListener("change", loadSamples);
    kindFilter.addEventListener("change", loadSamples);
    sceneFilter.addEventListener("change", loadSamples);

    async function api(path, options = {}) {
      if (!state.token) throw new Error("请先输入管理 Token");
      const response = await fetch(path, {
        ...options,
        headers: {
          "Authorization": "Bearer " + state.token,
          "Content-Type": "application/json",
          ...(options.headers || {})
        }
      });
      const text = await response.text();
      const data = text ? JSON.parse(text) : {};
      if (!response.ok) {
        throw new Error(data.error?.message || "请求失败");
      }
      return data;
    }

    async function loadAll() {
      try {
        await Promise.all([loadSummary(), loadAlerts(), loadSamples()]);
        toast("已刷新");
      } catch (error) {
        toast(error.message);
      }
    }

    async function loadSummary() {
      const data = await api("/api/admin/training/summary");
      const counts = Object.fromEntries((data.summary.statusCounts || []).map(row => [row.review_status, Number(row.sample_count)]));
      setText("pendingCount", counts.pending || 0);
      setText("approvedCount", counts.approved || 0);
      setText("rejectedCount", counts.rejected || 0);
      setText("usedCount", counts.used_in_training || 0);
      setText("alertBadge", data.summary.openAlertCount || 0);
      document.getElementById("alertBadge").classList.toggle("hot", Number(data.summary.openAlertCount || 0) > 0);
      const threshold = data.summary.settings?.trainingReadySceneThreshold || 300;
      const cloudEnhancementEnabled = data.summary.settings?.cloudEnhancementEnabled !== false;
      thresholdInput.value = String(threshold);
      cloudEnhancementToggle.checked = cloudEnhancementEnabled;
      setText("thresholdHelp", "当前阈值：" + threshold + " 条 approved 样本。达到后会生成训练提醒。");
      setText("cloudEnhancementHelp", cloudEnhancementEnabled ? "当前状态：云端增强已开启。" : "当前状态：云端增强已关闭，用户会看到“云端增强暂时繁忙”。");
    }

    async function loadAlerts() {
      const data = await api("/api/admin/training/readiness/alerts");
      const alerts = data.alerts || [];
      const openAlerts = alerts.filter(alert => alert.status === "open");
      setText("openAlertCount", openAlerts.length);
      document.getElementById("openAlertCount").classList.toggle("hot", openAlerts.length > 0);
      renderAlerts(alerts);
      showReminderIfNeeded(openAlerts.length);
    }

    async function loadSamples() {
      const params = new URLSearchParams({
        status: statusFilter.value,
        limit: "50"
      });
      if (kindFilter.value) params.set("kind", kindFilter.value);
      if (sceneFilter.value.trim()) params.set("scene", sceneFilter.value.trim());
      const data = await api("/api/admin/training/samples?" + params.toString());
      state.selectedSampleIds.clear();
      renderSamples(data.samples || []);
    }

    async function runReadinessCheck() {
      try {
        const data = await api("/api/admin/training/readiness/run", { method: "POST", body: "{}" });
        toast("检查完成，新提醒 " + data.result.createdAlerts + " 条");
        await loadAll();
      } catch (error) {
        toast(error.message);
      }
    }

    async function saveThreshold() {
      const value = Number(thresholdInput.value);
      if (!Number.isInteger(value) || value < 10 || value > 10000) {
        toast("阈值需要是 10 到 10000 的整数");
        return;
      }

      try {
        const data = await api("/api/admin/training/settings", {
          method: "POST",
          body: JSON.stringify({ trainingReadySceneThreshold: value })
        });
        toast("阈值已保存：" + data.settings.trainingReadySceneThreshold);
        await loadAll();
      } catch (error) {
        toast(error.message);
      }
    }

    async function saveCloudEnhancementToggle() {
      try {
        const data = await api("/api/admin/training/settings", {
          method: "POST",
          body: JSON.stringify({ cloudEnhancementEnabled: cloudEnhancementToggle.checked })
        });
        toast(data.settings.cloudEnhancementEnabled ? "云端增强已开启" : "云端增强已关闭");
        await loadAll();
      } catch (error) {
        toast(error.message);
      }
    }

    async function reviewSample(sampleId, reviewStatus) {
      try {
        await api("/api/admin/training/review-sample", {
          method: "POST",
          body: JSON.stringify({ sampleId, reviewStatus, reviewedBy: "Station Cat" })
        });
        toast("样本已更新为 " + reviewStatus);
        await loadAll();
      } catch (error) {
        toast(error.message);
      }
    }

    async function reviewSelectedSamples(reviewStatus) {
      const sampleIds = Array.from(state.selectedSampleIds);
      if (!sampleIds.length) {
        toast("请先选择要审核的样本");
        return;
      }

      try {
        const data = await api("/api/admin/training/review-samples", {
          method: "POST",
          body: JSON.stringify({ sampleIds, reviewStatus, reviewedBy: "Station Cat" })
        });
        toast("已批量更新 " + data.updatedCount + " 个样本");
        await loadAll();
      } catch (error) {
        toast(error.message);
      }
    }

    async function downloadExport(format) {
      if (!state.token) {
        toast("请先输入管理 Token");
        return;
      }

      const params = new URLSearchParams({
        format,
        status: statusFilter.value
      });
      if (kindFilter.value) params.set("kind", kindFilter.value);
      if (sceneFilter.value.trim()) params.set("scene", sceneFilter.value.trim());

      try {
        const response = await fetch("/api/admin/training/export?" + params.toString(), {
          headers: { "Authorization": "Bearer " + state.token }
        });
        const text = await response.text();
        if (!response.ok) {
          const data = text ? JSON.parse(text) : {};
          throw new Error(data.error?.message || "导出失败");
        }

        const body = format === "json" ? JSON.stringify(JSON.parse(text), null, 2) : text;
        const mime = format === "json" ? "application/json;charset=utf-8" : "text/csv;charset=utf-8";
        const filename = [
          "snapcopy-training",
          statusFilter.value || "all",
          kindFilter.value || "all",
          sceneFilter.value.trim() || "all",
          new Date().toISOString().slice(0, 10)
        ].join("-") + "." + format;
        downloadTextFile(body, mime, filename);
        toast("已开始导出 " + format.toUpperCase());
      } catch (error) {
        toast(error.message);
      }
    }

    function downloadTextFile(text, mime, filename) {
      const blob = new Blob([text], { type: mime });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    }

    function toggleSelectAllSamples() {
      if (selectAllSamples.checked) {
        state.visibleSampleIds.forEach(sampleId => state.selectedSampleIds.add(sampleId));
      } else {
        state.visibleSampleIds.forEach(sampleId => state.selectedSampleIds.delete(sampleId));
      }
      updateSelectionState();
    }

    function toggleSampleSelection(sampleId, isSelected) {
      if (isSelected) {
        state.selectedSampleIds.add(sampleId);
      } else {
        state.selectedSampleIds.delete(sampleId);
      }
      updateSelectionState();
    }

    async function acknowledgeAlert(alertId) {
      try {
        await api("/api/admin/training/readiness/ack", {
          method: "POST",
          body: JSON.stringify({ alertId })
        });
        toast("提醒已处理");
        await loadAll();
      } catch (error) {
        toast(error.message);
      }
    }

    function renderAlerts(alerts) {
      const container = document.getElementById("alerts");
      if (!alerts.length) {
        container.innerHTML = '<div class="empty">暂无训练提醒。达到阈值后会出现在这里。</div>';
        return;
      }

      container.innerHTML = alerts.map(alert => [
        '<article class="item">',
          '<div class="item-head">',
            '<div>',
              '<div class="item-title">' + escapeHtml(alert.message || "训练数据已达到阈值") + '</div>',
              '<div class="item-meta">' + escapeHtml(alert.kind) + ' / ' + escapeHtml(alert.scene) + ' · ' + escapeHtml(alert.status) + ' · ' + escapeHtml(alert.created_at) + '</div>',
            '</div>',
            '<span class="badge ' + (alert.status === "open" ? "hot" : "") + '">' + escapeHtml(alert.status) + '</span>',
          '</div>',
          alert.status === "open" ? '<div class="item-actions"><button class="ghost" onclick="acknowledgeAlert(\'' + escapeAttr(alert.alert_id) + '\')">标记已处理</button></div>' : "",
        '</article>'
      ].join("")).join("");
    }

    function renderSamples(samples) {
      const container = document.getElementById("samples");
      state.visibleSampleIds = samples.map(sample => sample.sample_id);
      updateSelectionState();
      if (!samples.length) {
        container.innerHTML = '<div class="empty">当前筛选条件下没有样本。</div>';
        return;
      }

      container.innerHTML = samples.map(sample => [
        '<article class="item" data-sample-id="' + escapeAttr(sample.sample_id) + '">',
          '<div class="item-head">',
            '<label class="sample-select" title="选择样本">',
              '<input class="sample-checkbox" type="checkbox" value="' + escapeAttr(sample.sample_id) + '" onchange="toggleSampleSelection(\'' + escapeAttr(sample.sample_id) + '\', this.checked)">',
            '</label>',
            '<div>',
              '<div class="item-title">' + escapeHtml(sample.kind) + ' · ' + escapeHtml(sample.scene || "unknown") + '</div>',
              '<div class="item-meta">' +
                escapeHtml(sample.sample_id) + '<br>' +
                escapeHtml(sample.source) + ' · ' + escapeHtml(sample.locale) + ' · ' + escapeHtml(sample.target_platform || "general") + ' · confidence ' + escapeHtml(sample.scene_confidence ?? "-") + '<br>' +
                (sample.r2_object_key ? "R2: " + escapeHtml(sample.r2_object_key) : escapeHtml(sample.privacy_redaction_status || "metadata")) +
              '</div>',
            '</div>',
            '<span class="badge">' + escapeHtml(sample.review_status) + '</span>',
          '</div>',
          sample.caption_text ? '<div class="caption-preview">' + escapeHtml(sample.caption_text).slice(0, 600) + '</div>' : "",
          '<div class="item-actions">',
            '<button class="good" onclick="reviewSample(\'' + escapeAttr(sample.sample_id) + '\',\'approved\')">通过</button>',
            '<button class="bad" onclick="reviewSample(\'' + escapeAttr(sample.sample_id) + '\',\'rejected\')">拒绝</button>',
            '<button class="ghost" onclick="reviewSample(\'' + escapeAttr(sample.sample_id) + '\',\'used_in_training\')">标记已训练</button>',
          '</div>',
        '</article>'
      ].join("")).join("");
      updateSelectionState();
    }

    function updateSelectionState() {
      const visibleSet = new Set(state.visibleSampleIds);
      for (const sampleId of Array.from(state.selectedSampleIds)) {
        if (!visibleSet.has(sampleId)) state.selectedSampleIds.delete(sampleId);
      }

      const selectedVisibleCount = state.visibleSampleIds.filter(sampleId => state.selectedSampleIds.has(sampleId)).length;
      setText("selectedCount", selectedVisibleCount);
      setText("visibleCount", state.visibleSampleIds.length);
      selectAllSamples.checked = state.visibleSampleIds.length > 0 && selectedVisibleCount === state.visibleSampleIds.length;
      selectAllSamples.indeterminate = selectedVisibleCount > 0 && selectedVisibleCount < state.visibleSampleIds.length;

      const hasSelection = selectedVisibleCount > 0;
      bulkApproveButton.disabled = !hasSelection;
      bulkRejectButton.disabled = !hasSelection;
      bulkUsedButton.disabled = !hasSelection;

      document.querySelectorAll("[data-sample-id]").forEach(item => {
        item.classList.toggle("selected", state.selectedSampleIds.has(item.dataset.sampleId));
      });
      document.querySelectorAll(".sample-checkbox").forEach(checkbox => {
        checkbox.checked = state.selectedSampleIds.has(checkbox.value);
      });
    }

    function showReminderIfNeeded(openCount) {
      const notice = document.getElementById("notice");
      if (openCount > 0) {
        notice.hidden = false;
        notice.textContent = "有 " + openCount + " 条训练提醒待处理。建议先查看提醒，再导出对应场景的样本。";
      } else {
        notice.hidden = true;
      }

      if (openCount > state.lastOpenAlertCount) {
        toast("出现新的训练提醒");
      }
      state.lastOpenAlertCount = openCount;
      localStorage.setItem("snapcopyLastOpenAlertCount", String(openCount));
    }

    function setText(id, value) {
      document.getElementById(id).textContent = String(value);
    }

    function toast(message) {
      const el = document.getElementById("toast");
      el.textContent = message;
      el.classList.add("show");
      setTimeout(() => el.classList.remove("show"), 2400);
    }

    function escapeHtml(value) {
      return String(value ?? "").replace(/[&<>"']/g, char => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;"
      }[char]));
    }

    function escapeAttr(value) {
      return escapeHtml(value).replace(new RegExp(String.fromCharCode(96), "g"), "&#96;");
    }

    if (state.token) loadAll();
    setInterval(() => {
      if (state.token) loadAll();
    }, 60000);
  </script>
</body>
</html>`;
