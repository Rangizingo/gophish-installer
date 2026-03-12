// ==UserScript==
// @name         GoPhish Report Generator
// @namespace    gophish-reports
// @version      1.0
// @description  Generates branded phishing simulation reports from GoPhish campaigns
// @match        https://localhost:3333/*
// @match        https://127.0.0.1:3333/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function() {
    'use strict';

    // ─── CONFIGURATION ───────────────────────────────────────────────
    var BRAND = {
        red: '#C41230',
        redDark: '#A50F2A',
        black: '#000000',
        darkText: '#1B1B1B',
        grayText: '#605E5C',
        lightBg: '#F8F8F8',
        white: '#FFFFFF',
        company: 'Restaurant Equippers',
        subtitle: 'WAREHOUSE STORES'
    };

    var STATUS_COLORS = {
        sent:      '#1abc9c',
        opened:    '#f9bf3b',
        clicked:   '#F39C12',
        submitted: '#f05b4f',
        reported:  '#45d6ef',
        error:     '#6c7a89'
    };

    // ─── UTILITIES ───────────────────────────────────────────────────

    function formatDate(dateStr) {
        var d = new Date(dateStr);
        return d.toLocaleDateString('en-US', {
            year: 'numeric', month: 'long', day: 'numeric',
            hour: '2-digit', minute: '2-digit'
        });
    }

    function formatShortDate(dateStr) {
        var d = new Date(dateStr);
        return d.toLocaleDateString('en-US', {
            year: 'numeric', month: 'short', day: 'numeric'
        });
    }

    function pct(count, total) {
        if (total === 0) return '0%';
        return Math.round((count / total) * 100) + '%';
    }

    function pctNum(count, total) {
        if (total === 0) return 0;
        return Math.round((count / total) * 100);
    }

    function escapeHTML(str) {
        var div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }

    function getStatusCounts(results) {
        var total = results.length;
        var opened = 0, clicked = 0, submitted = 0, reported = 0, errored = 0;

        results.forEach(function(r) {
            var s = r.status;
            if (s === 'Email Opened' || s === 'Clicked Link' || s === 'Submitted Data') opened++;
            if (s === 'Clicked Link' || s === 'Submitted Data') clicked++;
            if (s === 'Submitted Data') submitted++;
            if (s === 'Email Reported') reported++;
            if (s === 'Error' || s === 'Sending Error') errored++;
        });

        return { sent: total, opened: opened, clicked: clicked, submitted: submitted, reported: reported, error: errored };
    }

    function parseSubmittedData(timeline) {
        var submissions = [];
        timeline.forEach(function(event) {
            if (event.message === 'Submitted Data' && event.details) {
                try {
                    var details = JSON.parse(event.details);
                    submissions.push({
                        email: event.email,
                        time: event.time,
                        payload: details.payload || {},
                        browser: details.browser || {}
                    });
                } catch(e) { /* skip malformed */ }
            }
        });
        return submissions;
    }

    function getCredentialFields(submissions) {
        var fieldSet = {};
        submissions.forEach(function(s) {
            Object.keys(s.payload).forEach(function(k) {
                if (k !== 'rid' && k !== 'email') fieldSet[k] = true;
            });
        });
        // Order: password first, then new_password, confirm_password, then anything else
        var priority = ['password', 'new_password', 'confirm_password'];
        var keys = Object.keys(fieldSet);
        keys.sort(function(a, b) {
            var ai = priority.indexOf(a), bi = priority.indexOf(b);
            if (ai === -1) ai = 99;
            if (bi === -1) bi = 99;
            return ai - bi;
        });
        return keys;
    }

    function getRiskLevel(submittedPct) {
        if (submittedPct >= 50) return { label: 'CRITICAL', color: '#d32f2f', bg: '#ffebee' };
        if (submittedPct >= 25) return { label: 'HIGH', color: '#e65100', bg: '#fff3e0' };
        if (submittedPct >= 10) return { label: 'MODERATE', color: '#f9a825', bg: '#fffde7' };
        return { label: 'LOW', color: '#2e7d32', bg: '#e8f5e9' };
    }

    function fieldLabel(key) {
        var labels = {
            'password': 'Password',
            'new_password': 'New Password',
            'confirm_password': 'Confirm Password'
        };
        return labels[key] || key;
    }

    // ─── SVG DONUT CHART ─────────────────────────────────────────────

    function generateDonutSVG(segments, size, centerText) {
        var total = 0;
        segments.forEach(function(s) { total += s.value; });

        if (total === 0) {
            return '<svg viewBox="0 0 ' + size + ' ' + size + '" width="' + size + '" height="' + size + '">' +
                '<circle cx="' + (size/2) + '" cy="' + (size/2) + '" r="' + (size/2 - 14) + '" fill="none" stroke="#e5e5e5" stroke-width="20"/>' +
                '<text x="' + (size/2) + '" y="' + (size/2) + '" text-anchor="middle" dominant-baseline="central" ' +
                'font-family="Segoe UI, sans-serif" font-size="24" fill="#605E5C">0</text></svg>';
        }

        var cx = size / 2, cy = size / 2;
        var outerR = size / 2 - 4;
        var innerR = outerR * 0.65;
        var startAngle = -Math.PI / 2;
        var paths = '';

        segments.forEach(function(seg) {
            if (seg.value === 0) return;
            var angle = (seg.value / total) * 2 * Math.PI;
            var endAngle = startAngle + angle;
            var largeArc = angle > Math.PI ? 1 : 0;

            if (seg.value === total) {
                var midR = (outerR + innerR) / 2;
                paths += '<circle cx="' + cx + '" cy="' + cy + '" r="' + midR + '" fill="none" stroke="' + seg.color + '" stroke-width="' + (outerR - innerR) + '"/>';
            } else {
                var x1o = cx + outerR * Math.cos(startAngle);
                var y1o = cy + outerR * Math.sin(startAngle);
                var x2o = cx + outerR * Math.cos(endAngle);
                var y2o = cy + outerR * Math.sin(endAngle);
                var x1i = cx + innerR * Math.cos(endAngle);
                var y1i = cy + innerR * Math.sin(endAngle);
                var x2i = cx + innerR * Math.cos(startAngle);
                var y2i = cy + innerR * Math.sin(startAngle);

                paths += '<path d="M' + x1o.toFixed(2) + ',' + y1o.toFixed(2) +
                    ' A' + outerR + ',' + outerR + ' 0 ' + largeArc + ' 1 ' + x2o.toFixed(2) + ',' + y2o.toFixed(2) +
                    ' L' + x1i.toFixed(2) + ',' + y1i.toFixed(2) +
                    ' A' + innerR + ',' + innerR + ' 0 ' + largeArc + ' 0 ' + x2i.toFixed(2) + ',' + y2i.toFixed(2) +
                    ' Z" fill="' + seg.color + '"/>';
            }
            startAngle = endAngle;
        });

        return '<svg viewBox="0 0 ' + size + ' ' + size + '" width="' + size + '" height="' + size + '" xmlns="http://www.w3.org/2000/svg">' +
            paths +
            '<text x="' + cx + '" y="' + (cy - 8) + '" text-anchor="middle" dominant-baseline="central" ' +
            'font-family="Segoe UI, sans-serif" font-size="28" font-weight="700" fill="' + BRAND.darkText + '">' + total + '</text>' +
            '<text x="' + cx + '" y="' + (cy + 14) + '" text-anchor="middle" dominant-baseline="central" ' +
            'font-family="Segoe UI, sans-serif" font-size="11" fill="' + BRAND.grayText + '">' + (centerText || 'Total') + '</text></svg>';
    }

    // ─── API FUNCTIONS ───────────────────────────────────────────────

    function getApiHeaders() {
        // GoPhish stores the API key in the global user object
        var headers = { 'Content-Type': 'application/json' };
        if (typeof user !== 'undefined' && user.api_key) {
            headers['Authorization'] = 'Bearer ' + user.api_key;
        }
        return headers;
    }

    function fetchAllCampaigns() {
        return fetch('/api/campaigns/', { credentials: 'same-origin', headers: getApiHeaders() })
            .then(function(resp) {
                if (!resp.ok) throw new Error('Failed to fetch campaigns');
                return resp.json();
            });
    }

    function fetchCampaign(id) {
        return fetch('/api/campaigns/' + id, { credentials: 'same-origin', headers: getApiHeaders() })
            .then(function(resp) {
                if (!resp.ok) throw new Error('Failed to fetch campaign ' + id);
                return resp.json();
            });
    }

    // ─── REPORT HTML GENERATION ──────────────────────────────────────

    function generateReportHTML(campaigns) {
        var reportDate = formatDate(new Date().toISOString());
        var fileDate = new Date().toISOString().split('T')[0];

        // Aggregate stats
        var totalSent = 0, totalOpened = 0, totalClicked = 0, totalSubmitted = 0;
        campaigns.forEach(function(c) {
            var counts = getStatusCounts(c.results || []);
            totalSent += counts.sent;
            totalOpened += counts.opened;
            totalClicked += counts.clicked;
            totalSubmitted += counts.submitted;
        });

        var risk = getRiskLevel(pctNum(totalSubmitted, totalSent));

        var overallSegments = [
            { value: totalSent - totalOpened, color: STATUS_COLORS.sent },
            { value: totalOpened - totalClicked, color: STATUS_COLORS.opened },
            { value: totalClicked - totalSubmitted, color: STATUS_COLORS.clicked },
            { value: totalSubmitted, color: STATUS_COLORS.submitted }
        ];

        // Build campaign sections
        var campaignSections = '';
        campaigns.forEach(function(c) {
            campaignSections += generateCampaignSectionHTML(c);
        });

        // Executive summary (shown for multi-campaign, or single with summary)
        var execSummary = '';
        if (campaigns.length > 1) {
            execSummary = '<div class="exec-summary">' +
                '<h2>Executive Summary</h2>' +
                '<div class="risk-banner" style="background:' + risk.bg + '; border-left:4px solid ' + risk.color + '; padding:16px 20px; margin-bottom:24px; display:flex; align-items:center; gap:16px;">' +
                    '<div style="font-size:13px; font-weight:700; color:' + risk.color + '; letter-spacing:1px;">' + risk.label + ' RISK</div>' +
                    '<div style="font-size:13px; color:' + BRAND.darkText + ';">' + pct(totalSubmitted, totalSent) + ' of recipients submitted credentials across ' + campaigns.length + ' campaigns</div>' +
                '</div>' +
                '<div class="summary-grid">' +
                    '<div class="summary-chart">' + generateDonutSVG(overallSegments, 160, 'Recipients') + '</div>' +
                    '<div>' +
                        '<div class="stat-cards">' +
                            statCard(totalSent, '100%', 'Emails Sent', STATUS_COLORS.sent) +
                            statCard(totalOpened, pct(totalOpened, totalSent), 'Opened', STATUS_COLORS.opened) +
                            statCard(totalClicked, pct(totalClicked, totalSent), 'Clicked Link', STATUS_COLORS.clicked) +
                            statCard(totalSubmitted, pct(totalSubmitted, totalSent), 'Submitted Data', STATUS_COLORS.submitted) +
                        '</div>' +
                        '<div class="legend">' +
                            legendItem(STATUS_COLORS.sent, 'Sent Only') +
                            legendItem(STATUS_COLORS.opened, 'Opened') +
                            legendItem(STATUS_COLORS.clicked, 'Clicked') +
                            legendItem(STATUS_COLORS.submitted, 'Submitted') +
                        '</div>' +
                    '</div>' +
                '</div>' +
            '</div>';
        }

        return '<!DOCTYPE html>\n<html lang="en">\n<head>\n' +
            '<meta charset="UTF-8">\n' +
            '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n' +
            '<title>Phishing Simulation Report - ' + escapeHTML(BRAND.company) + '</title>\n' +
            '<style>\n' + getReportCSS() + '\n</style>\n' +
            '</head>\n<body>\n' +
            '<div class="report">\n' +

            // Header
            '<div class="report-header">' +
                '<div class="logo-row">' +
                    '<div class="company-name">' +
                        '<div class="line1">RESTAURANT</div>' +
                        '<div class="line2">EQUIPPERS</div>' +
                        '<div class="line3">WAREHOUSE STORES</div>' +
                    '</div>' +
                    '<div class="confidential">CONFIDENTIAL</div>' +
                '</div>' +
                '<h1>Phishing Simulation Report</h1>' +
                '<div class="report-meta">Generated ' + reportDate + ' &bull; ' +
                    campaigns.length + ' campaign' + (campaigns.length !== 1 ? 's' : '') +
                    ' &bull; ' + totalSent + ' recipients</div>' +
            '</div>' +

            // Toolbar
            '<div class="toolbar" id="reportToolbar">' +
                '<button onclick="downloadReport()">&#10515; Download HTML</button>' +
                '<button onclick="window.print()">&#128438; Print / Save as PDF</button>' +
                '<div class="toolbar-spacer"></div>' +
                '' +
            '</div>' +

            // Body
            '<div class="report-body">' +
                execSummary +
                campaignSections +
            '</div>' +

            // Footer
            '<div class="report-footer">' +
                'Generated by GoPhish Report Generator &bull; ' + escapeHTML(BRAND.company) + ' &bull; ' + reportDate +
            '</div>' +

            '</div>\n' +

            // Scripts
            '<script>\n' +
            'function downloadReport() {\n' +
            '    var toolbar = document.getElementById("reportToolbar");\n' +
            '    toolbar.style.display = "none";\n' +
            '    var html = "<!DOCTYPE html>" + document.documentElement.outerHTML;\n' +
            '    toolbar.style.display = "";\n' +
            '    var blob = new Blob([html], { type: "text/html" });\n' +
            '    var url = URL.createObjectURL(blob);\n' +
            '    var a = document.createElement("a");\n' +
            '    a.href = url;\n' +
            '    a.download = "phishing-report-' + fileDate + '.html";\n' +
            '    a.click();\n' +
            '    URL.revokeObjectURL(url);\n' +
            '}\n' +
            '' +
            '</script>\n' +
            '</body>\n</html>';
    }

    function statCard(value, pctStr, label, color) {
        return '<div class="stat-card">' +
            '<div class="stat-value" style="color:' + color + '">' + value + '</div>' +
            '<div class="stat-pct">' + pctStr + '</div>' +
            '<div class="stat-label">' + label + '</div>' +
        '</div>';
    }

    function legendItem(color, label) {
        return '<div class="legend-item"><div class="legend-dot" style="background:' + color + '"></div> ' + label + '</div>';
    }

    function generateCampaignSectionHTML(campaign) {
        var results = campaign.results || [];
        var timeline = campaign.timeline || [];
        var counts = getStatusCounts(results);
        var submissions = parseSubmittedData(timeline);
        var risk = getRiskLevel(pctNum(counts.submitted, counts.sent));

        var statusClass = campaign.status === 'Completed' ? 'status-completed' : 'status-active';

        var segments = [
            { value: counts.sent - counts.opened, color: STATUS_COLORS.sent },
            { value: counts.opened - counts.clicked, color: STATUS_COLORS.opened },
            { value: counts.clicked - counts.submitted, color: STATUS_COLORS.clicked },
            { value: counts.submitted, color: STATUS_COLORS.submitted }
        ];

        // Sort results: submitted first, then clicked, opened, sent
        var statusOrder = { 'Submitted Data': 0, 'Clicked Link': 1, 'Email Opened': 2, 'Email Sent': 3, 'Error': 4, 'Sending Error': 5 };
        var sortedResults = results.slice().sort(function(a, b) {
            return (statusOrder[a.status] || 99) - (statusOrder[b.status] || 99);
        });

        // Results table rows
        var resultsRows = '';
        sortedResults.forEach(function(r) {
            resultsRows += '<tr>' +
                '<td>' + escapeHTML(r.first_name + ' ' + r.last_name) + '</td>' +
                '<td>' + escapeHTML(r.email) + '</td>' +
                '<td>' + escapeHTML(r.position || '-') + '</td>' +
                '<td><span class="status-badge ' + getBadgeClass(r.status) + '">' + escapeHTML(r.status) + '</span></td>' +
            '</tr>';
        });

        // Credentials section
        var credsSection = '';
        if (submissions.length > 0) {
            var credFields = getCredentialFields(submissions);

            var credsHeader = '<th>Email</th>';
            credFields.forEach(function(f) {
                credsHeader += '<th>' + escapeHTML(fieldLabel(f)) + '</th>';
            });
            credsHeader += '<th>Time</th><th>Source IP</th>';

            var credsRows = '';
            submissions.forEach(function(s) {
                var email = (s.payload.email && s.payload.email[0]) || s.email;
                var time = new Date(s.time).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
                var ip = s.browser.address || '';

                credsRows += '<tr><td>' + escapeHTML(email) + '</td>';
                credFields.forEach(function(f) {
                    var val = s.payload[f];
                    var display = '';
                    if (Array.isArray(val)) {
                        display = val.join(', ');
                    } else if (val) {
                        display = String(val);
                    }
                    credsRows += '<td style="color:#999; font-style:italic;">REDACTED</td>';
                });
                credsRows += '<td>' + escapeHTML(time) + '</td>';
                credsRows += '<td style="font-size:11px;">' + escapeHTML(ip) + '</td>';
                credsRows += '</tr>';
            });

            credsSection = '<div class="creds-section">' +
                '<h4>&#9888;&#65039; Captured Credentials (' + submissions.length + ')</h4>' +
                '<table class="creds-table"><tr>' + credsHeader + '</tr>' + credsRows + '</table>' +
            '</div>';
        }

        return '<div class="campaign-section">' +
            '<div class="campaign-header">' +
                '<h2>' + escapeHTML(campaign.name) + '</h2>' +
                '<div style="display:flex; align-items:center; gap:12px;">' +
                    '<span class="risk-tag" style="background:' + risk.bg + '; color:' + risk.color + '; padding:4px 10px; font-size:11px; font-weight:700; border-radius:2px; letter-spacing:0.5px;">' + risk.label + '</span>' +
                    '<span class="campaign-status ' + statusClass + '">' + escapeHTML(campaign.status || 'In Progress') + '</span>' +
                '</div>' +
            '</div>' +
            '<div class="campaign-meta">' +
                '<span>Launched: ' + formatShortDate(campaign.launch_date) + '</span>' +
                '<span>URL: ' + escapeHTML(campaign.url || 'N/A') + '</span>' +
            '</div>' +
            '<div class="campaign-stats">' +
                '<div>' + generateDonutSVG(segments, 140, 'Targets') + '</div>' +
                '<div class="mini-stats">' +
                    miniStat(counts.sent, '100%', 'Sent', STATUS_COLORS.sent) +
                    miniStat(counts.opened, pct(counts.opened, counts.sent), 'Opened', STATUS_COLORS.opened) +
                    miniStat(counts.clicked, pct(counts.clicked, counts.sent), 'Clicked', STATUS_COLORS.clicked) +
                    miniStat(counts.submitted, pct(counts.submitted, counts.sent), 'Submitted', STATUS_COLORS.submitted) +
                '</div>' +
            '</div>' +
            credsSection +
            '<table class="results-table">' +
                '<tr><th>Name</th><th>Email</th><th>Position</th><th>Status</th></tr>' +
                resultsRows +
            '</table>' +
        '</div>';
    }

    function miniStat(value, pctStr, label, color) {
        return '<div class="mini-stat" style="border-top-color:' + color + '">' +
            '<div class="ms-value" style="color:' + color + '">' + value + '</div>' +
            '<div class="ms-pct">' + pctStr + '</div>' +
            '<div class="ms-label">' + label + '</div>' +
        '</div>';
    }

    function getBadgeClass(status) {
        switch(status) {
            case 'Email Sent': return 'badge-sent';
            case 'Email Opened': return 'badge-opened';
            case 'Clicked Link': return 'badge-clicked';
            case 'Submitted Data': return 'badge-submitted';
            case 'Email Reported': return 'badge-reported';
            default: return 'badge-error';
        }
    }

    function getReportCSS() {
        return '* { margin: 0; padding: 0; box-sizing: border-box; }\n' +
        'body { font-family: "Segoe UI", Roboto, -apple-system, sans-serif; color: ' + BRAND.darkText + '; background: #f0f0f0; }\n' +
        '.report { max-width: 1000px; margin: 0 auto; background: ' + BRAND.white + '; box-shadow: 0 2px 20px rgba(0,0,0,0.1); }\n' +

        // Header
        '.report-header { background: ' + BRAND.red + '; padding: 32px 48px; color: ' + BRAND.white + '; }\n' +
        '.report-header .logo-row { display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px; }\n' +
        '.report-header .company-name { font-family: "Arial Black", Arial, sans-serif; }\n' +
        '.report-header .company-name .line1 { font-size: 18px; letter-spacing: 1px; font-weight: 900; }\n' +
        '.report-header .company-name .line2 { font-size: 24px; letter-spacing: 1px; font-weight: 900; }\n' +
        '.report-header .company-name .line3 { font-size: 9px; letter-spacing: 2px; font-weight: 400; font-family: Arial, sans-serif; margin-top: 2px; }\n' +
        '.report-header .confidential { font-size: 11px; letter-spacing: 2px; text-transform: uppercase; opacity: 0.8; background: rgba(0,0,0,0.2); padding: 4px 12px; border-radius: 2px; }\n' +
        '.report-header h1 { font-size: 28px; font-weight: 300; letter-spacing: -0.5px; }\n' +
        '.report-header .report-meta { font-size: 14px; opacity: 0.85; margin-top: 8px; }\n' +

        // Toolbar
        '.toolbar { background: ' + BRAND.darkText + '; padding: 12px 48px; display: flex; gap: 12px; align-items: center; }\n' +
        '.toolbar button { background: ' + BRAND.white + '; color: ' + BRAND.darkText + '; border: none; padding: 8px 20px; font-size: 13px; font-family: "Segoe UI", sans-serif; font-weight: 600; cursor: pointer; border-radius: 2px; transition: background 0.15s; }\n' +
        '.toolbar button:hover { background: #e0e0e0; }\n' +
        '.toolbar .toolbar-spacer { flex: 1; }\n' +
        '.toolbar label { color: ' + BRAND.white + '; font-size: 13px; cursor: pointer; display: flex; align-items: center; gap: 6px; }\n' +
        '.toolbar input[type="checkbox"] { cursor: pointer; }\n' +

        // Body
        '.report-body { padding: 48px; }\n' +

        // Executive Summary
        '.exec-summary { margin-bottom: 48px; }\n' +
        '.exec-summary h2 { font-size: 20px; font-weight: 600; color: ' + BRAND.darkText + '; margin-bottom: 24px; padding-bottom: 8px; border-bottom: 3px solid ' + BRAND.red + '; }\n' +
        '.summary-grid { display: grid; grid-template-columns: 160px 1fr; gap: 32px; align-items: center; }\n' +
        '.stat-cards { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }\n' +
        '.stat-card { text-align: center; padding: 20px 12px; background: ' + BRAND.lightBg + '; border-radius: 4px; }\n' +
        '.stat-card .stat-value { font-size: 32px; font-weight: 700; }\n' +
        '.stat-card .stat-pct { font-size: 14px; color: ' + BRAND.grayText + '; margin-top: 2px; }\n' +
        '.stat-card .stat-label { font-size: 12px; color: ' + BRAND.grayText + '; margin-top: 8px; text-transform: uppercase; letter-spacing: 0.5px; }\n' +

        // Legend
        '.legend { display: flex; gap: 20px; flex-wrap: wrap; margin-top: 16px; }\n' +
        '.legend-item { display: flex; align-items: center; gap: 6px; font-size: 12px; color: ' + BRAND.grayText + '; }\n' +
        '.legend-dot { width: 12px; height: 12px; border-radius: 2px; }\n' +

        // Campaign Sections
        '.campaign-section { margin-bottom: 48px; page-break-inside: avoid; }\n' +
        '.campaign-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; padding-bottom: 8px; border-bottom: 3px solid ' + BRAND.red + '; }\n' +
        '.campaign-header h2 { font-size: 20px; font-weight: 600; }\n' +
        '.campaign-status { font-size: 12px; padding: 4px 12px; border-radius: 2px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }\n' +
        '.status-active { background: #e8f5e9; color: #2e7d32; }\n' +
        '.status-completed { background: #e3f2fd; color: #1565c0; }\n' +
        '.campaign-meta { font-size: 13px; color: ' + BRAND.grayText + '; margin-bottom: 20px; }\n' +
        '.campaign-meta span { margin-right: 24px; }\n' +

        // Campaign Stats
        '.campaign-stats { display: grid; grid-template-columns: 140px 1fr; gap: 24px; align-items: center; margin-bottom: 24px; }\n' +
        '.mini-stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }\n' +
        '.mini-stat { text-align: center; padding: 12px 8px; background: ' + BRAND.lightBg + '; border-radius: 4px; border-top: 3px solid transparent; }\n' +
        '.mini-stat .ms-value { font-size: 24px; font-weight: 700; }\n' +
        '.mini-stat .ms-pct { font-size: 12px; color: ' + BRAND.grayText + '; }\n' +
        '.mini-stat .ms-label { font-size: 11px; color: ' + BRAND.grayText + '; margin-top: 4px; text-transform: uppercase; }\n' +

        // Tables
        '.results-table { width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 24px; }\n' +
        '.results-table th { background: ' + BRAND.darkText + '; color: ' + BRAND.white + '; padding: 10px 14px; text-align: left; font-weight: 600; font-size: 12px; text-transform: uppercase; letter-spacing: 0.5px; }\n' +
        '.results-table td { padding: 10px 14px; border-bottom: 1px solid #e8e8e8; }\n' +
        '.results-table tr:hover td { background: #fafafa; }\n' +
        '.status-badge { display: inline-block; padding: 3px 10px; border-radius: 2px; font-size: 11px; font-weight: 600; color: ' + BRAND.white + '; white-space: nowrap; }\n' +
        '.badge-sent { background: ' + STATUS_COLORS.sent + '; }\n' +
        '.badge-opened { background: ' + STATUS_COLORS.opened + '; color: ' + BRAND.darkText + '; }\n' +
        '.badge-clicked { background: ' + STATUS_COLORS.clicked + '; }\n' +
        '.badge-submitted { background: ' + STATUS_COLORS.submitted + '; }\n' +
        '.badge-reported { background: ' + STATUS_COLORS.reported + '; }\n' +
        '.badge-error { background: ' + STATUS_COLORS.error + '; }\n' +

        // Credentials
        '.creds-section { background: #fff5f5; border: 1px solid #fecaca; border-radius: 4px; padding: 20px; margin-bottom: 24px; }\n' +
        '.creds-section h4 { font-size: 14px; color: ' + BRAND.red + '; margin-bottom: 12px; }\n' +
        '.creds-table { width: 100%; border-collapse: collapse; font-size: 13px; }\n' +
        '.creds-table th { background: ' + BRAND.red + '; color: ' + BRAND.white + '; padding: 8px 12px; text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; }\n' +
        '.creds-table td { padding: 8px 12px; border-bottom: 1px solid #fecaca; font-family: Consolas, "Courier New", monospace; }\n' +
        '.creds-table tr:last-child td { border-bottom: none; }\n' +
        '.redactable { transition: filter 0.2s; }\n' +

        // Footer
        '.report-footer { padding: 24px 48px; background: ' + BRAND.lightBg + '; border-top: 1px solid #e0e0e0; text-align: center; font-size: 12px; color: ' + BRAND.grayText + '; }\n' +

        // Print
        '@media print {\n' +
        '    body { background: white; }\n' +
        '    .report { box-shadow: none; }\n' +
        '    .toolbar { display: none !important; }\n' +
        '    .campaign-section { page-break-inside: avoid; }\n' +
        '    .redactable { filter: blur(5px) !important; }\n' +
        '}\n';
    }

    // ─── UI INJECTION ────────────────────────────────────────────────

    function getCurrentCampaignId() {
        var match = window.location.pathname.match(/^\/campaigns\/(\d+)/);
        return match ? parseInt(match[1]) : null;
    }

    function isResultsPage() {
        return getCurrentCampaignId() !== null;
    }

    function isCampaignsListPage() {
        return window.location.pathname === '/campaigns' || window.location.pathname === '/campaigns/';
    }

    function injectResultsPageButton() {
        var attempts = 0;
        var checkInterval = setInterval(function() {
            attempts++;
            if (attempts > 20) { clearInterval(checkInterval); return; }

            var exportBtn = document.getElementById('exportButton');
            if (!exportBtn) return;
            clearInterval(checkInterval);

            if (document.getElementById('generateReportBtn')) return;

            var btnGroup = exportBtn.closest('.btn-group');
            if (!btnGroup) return;

            var reportBtn = document.createElement('button');
            reportBtn.id = 'generateReportBtn';
            reportBtn.className = 'btn btn-primary';
            reportBtn.innerHTML = '<i class="fa fa-file-text-o"></i> Generate Report';
            reportBtn.style.marginLeft = '5px';
            reportBtn.addEventListener('click', function() {
                reportBtn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> Generating...';
                reportBtn.disabled = true;
                var campaignId = getCurrentCampaignId();
                fetchCampaign(campaignId).then(function(campaign) {
                    var html = generateReportHTML([campaign]);
                    var w = window.open('', '_blank');
                    w.document.write(html);
                    w.document.close();
                }).catch(function(err) {
                    alert('Error generating report: ' + err.message);
                }).finally(function() {
                    reportBtn.innerHTML = '<i class="fa fa-file-text-o"></i> Generate Report';
                    reportBtn.disabled = false;
                });
            });

            btnGroup.parentNode.insertBefore(reportBtn, btnGroup.nextSibling);
        }, 500);
    }

    function injectCampaignsListButton() {
        var attempts = 0;
        var checkInterval = setInterval(function() {
            attempts++;
            if (attempts > 20) { clearInterval(checkInterval); return; }

            var buttons = document.querySelectorAll('button[data-toggle="modal"]');
            var newCampaignBtn = null;
            buttons.forEach(function(btn) {
                if (btn.textContent.indexOf('New Campaign') !== -1) newCampaignBtn = btn;
            });
            if (!newCampaignBtn) return;
            clearInterval(checkInterval);

            if (document.getElementById('multiReportBtn')) return;

            var reportBtn = document.createElement('button');
            reportBtn.id = 'multiReportBtn';
            reportBtn.className = 'btn btn-primary';
            reportBtn.innerHTML = '<i class="fa fa-file-text-o"></i> Generate Report';
            reportBtn.style.marginLeft = '10px';
            reportBtn.addEventListener('click', showCampaignSelector);

            newCampaignBtn.parentNode.insertBefore(reportBtn, newCampaignBtn.nextSibling);
        }, 500);
    }

    function showCampaignSelector() {
        var btn = document.getElementById('multiReportBtn');
        if (btn) {
            btn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> Loading...';
            btn.disabled = true;
        }

        fetchAllCampaigns().then(function(campaigns) {
            if (btn) {
                btn.innerHTML = '<i class="fa fa-file-text-o"></i> Generate Report';
                btn.disabled = false;
            }

            // Remove existing modal
            var existing = document.getElementById('reportSelectorModal');
            if (existing) existing.remove();

            // Sort campaigns by ID descending (newest first)
            campaigns.sort(function(a, b) { return b.id - a.id; });

            // Build campaign list
            var listItems = '';
            campaigns.forEach(function(c) {
                var counts = getStatusCounts(c.results || []);
                var date = formatShortDate(c.launch_date);
                listItems += '<label class="list-group-item" style="display:flex; align-items:center; gap:12px; cursor:pointer; padding:10px 15px; margin-bottom:0;">' +
                    '<input type="checkbox" class="campaign-cb" value="' + c.id + '" checked style="width:16px; height:16px;">' +
                    '<div style="flex:1;">' +
                        '<strong>' + escapeHTML(c.name) + '</strong>' +
                        '<div style="font-size:12px; color:#888;">' + date + ' &bull; ' + counts.sent + ' targets &bull; ' + counts.submitted + ' submitted &bull; ' + escapeHTML(c.status) + '</div>' +
                    '</div>' +
                '</label>';
            });

            var modalHTML = '<div class="modal fade" id="reportSelectorModal" tabindex="-1" role="dialog">' +
                '<div class="modal-dialog" role="document">' +
                    '<div class="modal-content">' +
                        '<div class="modal-header">' +
                            '<button type="button" class="close" data-dismiss="modal">&times;</button>' +
                            '<h4 class="modal-title"><i class="fa fa-file-text-o"></i> Generate Report</h4>' +
                        '</div>' +
                        '<div class="modal-body">' +
                            '<p style="margin-bottom:12px;">Select campaigns to include in the report:</p>' +
                            '<div style="margin-bottom:12px;">' +
                                '<button class="btn btn-xs btn-default" id="rptSelectAll">Select All</button> ' +
                                '<button class="btn btn-xs btn-default" id="rptDeselectAll">Deselect All</button>' +
                            '</div>' +
                            '<div class="list-group" style="max-height:400px; overflow-y:auto; margin-bottom:0;">' +
                                listItems +
                            '</div>' +
                        '</div>' +
                        '<div class="modal-footer">' +
                            '<button type="button" class="btn btn-default" data-dismiss="modal">Cancel</button>' +
                            '<button type="button" class="btn btn-primary" id="rptGenerate">' +
                                '<i class="fa fa-file-text-o"></i> Generate Report' +
                            '</button>' +
                        '</div>' +
                    '</div>' +
                '</div>' +
            '</div>';

            document.body.insertAdjacentHTML('beforeend', modalHTML);

            var modal = document.getElementById('reportSelectorModal');
            $(modal).modal('show');

            document.getElementById('rptSelectAll').addEventListener('click', function() {
                modal.querySelectorAll('.campaign-cb').forEach(function(cb) { cb.checked = true; });
            });
            document.getElementById('rptDeselectAll').addEventListener('click', function() {
                modal.querySelectorAll('.campaign-cb').forEach(function(cb) { cb.checked = false; });
            });

            document.getElementById('rptGenerate').addEventListener('click', function() {
                var genBtn = this;
                var selectedIds = [];
                modal.querySelectorAll('.campaign-cb:checked').forEach(function(cb) {
                    selectedIds.push(parseInt(cb.value));
                });

                if (selectedIds.length === 0) {
                    alert('Please select at least one campaign.');
                    return;
                }

                genBtn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> Generating...';
                genBtn.disabled = true;

                var selectedCampaigns = campaigns.filter(function(c) {
                    return selectedIds.indexOf(c.id) !== -1;
                });
                // Sort by launch date ascending for the report
                selectedCampaigns.sort(function(a, b) {
                    return new Date(a.launch_date) - new Date(b.launch_date);
                });

                var html = generateReportHTML(selectedCampaigns);
                var w = window.open('', '_blank');
                w.document.write(html);
                w.document.close();
                $(modal).modal('hide');
            });

            $(modal).on('hidden.bs.modal', function() {
                modal.remove();
            });

        }).catch(function(err) {
            if (btn) {
                btn.innerHTML = '<i class="fa fa-file-text-o"></i> Generate Report';
                btn.disabled = false;
            }
            alert('Error loading campaigns: ' + err.message);
        });
    }

    // ─── INITIALIZATION ──────────────────────────────────────────────

    function init() {
        if (isResultsPage()) {
            injectResultsPageButton();
        } else if (isCampaignsListPage()) {
            injectCampaignsListButton();
        }

        // Handle navigation without full page reload
        var lastPath = window.location.pathname;
        setInterval(function() {
            if (window.location.pathname !== lastPath) {
                lastPath = window.location.pathname;
                if (isResultsPage()) injectResultsPageButton();
                else if (isCampaignsListPage()) injectCampaignsListButton();
            }
        }, 1000);
    }

    if (document.readyState === 'complete') {
        init();
    } else {
        window.addEventListener('load', init);
    }

})();
