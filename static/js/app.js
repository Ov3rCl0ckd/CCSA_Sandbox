document.addEventListener('DOMContentLoaded', () => {
  fetch('data/challenges.json')
    .then(response => response.json())
    .then(challenges => {
      const container = document.getElementById('challenges-container');
      container.innerHTML = '';

      challenges.forEach(ch => {
        const card = document.createElement('div');
        card.className = 'challenge-card';

        // VM-1 Render
        let vm1Commands = '';
        ch.vm1.commands.forEach(c => {
          vm1Commands += `
            <div class="command-row">
              <div class="command-label">${escapeHtml(c.label)}</div>
              <div class="terminal-box">
                <code>${escapeHtml(c.cmd)}</code>
                <button class="copy-btn" onclick="copyCommand(this, \`${escapeJs(c.cmd)}\`)">Copy</button>
              </div>
            </div>
          `;
        });

        let vm1Downloads = '';
        ch.vm1.downloads.forEach(d => {
          vm1Downloads += `
            <a href="${escapeHtml(d.path)}" download class="download-pill">
              📥 ${escapeHtml(d.name)}
            </a>
          `;
        });

        let vm1Dos = '';
        ch.vm1.dos.forEach(item => { vm1Dos += `<li>${escapeHtml(item)}</li>`; });
        let vm1Donts = '';
        ch.vm1.donts.forEach(item => { vm1Donts += `<li>${escapeHtml(item)}</li>`; });


        // VM-2 Render
        let vm2Commands = '';
        ch.vm2.commands.forEach(c => {
          vm2Commands += `
            <div class="command-row">
              <div class="command-label">${escapeHtml(c.label)}</div>
              <div class="terminal-box">
                <code>${escapeHtml(c.cmd)}</code>
                <button class="copy-btn" onclick="copyCommand(this, \`${escapeJs(c.cmd)}\`)">Copy</button>
              </div>
            </div>
          `;
        });

        let vm2Downloads = '';
        ch.vm2.downloads.forEach(d => {
          vm2Downloads += `
            <a href="${escapeHtml(d.path)}" download class="download-pill">
              📥 ${escapeHtml(d.name)}
            </a>
          `;
        });

        let vm2Dos = '';
        ch.vm2.dos.forEach(item => { vm2Dos += `<li>${escapeHtml(item)}</li>`; });
        let vm2Donts = '';
        ch.vm2.donts.forEach(item => { vm2Donts += `<li>${escapeHtml(item)}</li>`; });

        card.innerHTML = `
          <div class="card-header">
            <div class="card-title-group">
              <h3>${escapeHtml(ch.title)}</h3>
              <div class="subtitle">Lab ID: ${escapeHtml(ch.id)}</div>
            </div>
            <div class="card-meta">
              <span class="tag tag-cat">${escapeHtml(ch.category)}</span>
              <span class="tag tag-diff">${escapeHtml(ch.difficulty)}</span>
            </div>
          </div>
          <div class="card-body">
            <div class="lab-overview">
              <strong>📖 Lab Overview:</strong> ${escapeHtml(ch.overview)}
            </div>

            <div class="vm-split-container">
              <!-- VM-1 Column -->
              <div class="vm-column red-vm">
                <h4>${escapeHtml(ch.vm1.title)}</h4>
                <p class="vm-goal"><strong>Mission Objective:</strong> ${escapeHtml(ch.vm1.goal)}</p>

                <div class="guidelines-box dos">
                  <h5>What to do (Best Practices)</h5>
                  <ul>${vm1Dos}</ul>
                </div>

                <div class="guidelines-box donts">
                  <h5>What NOT to do (Safety & Pitfalls)</h5>
                  <ul>${vm1Donts}</ul>
                </div>

                <div class="commands-section">
                  <h5>⚡ Red Team Terminal Commands</h5>
                  ${vm1Commands}
                </div>

                <div class="downloads-section">
                  <h5>📂 Red Team File Downloads</h5>
                  <div class="download-pills">
                    ${vm1Downloads}
                  </div>
                </div>
              </div>

              <!-- VM-2 Column -->
              <div class="vm-column blue-vm">
                <h4>${escapeHtml(ch.vm2.title)}</h4>
                <p class="vm-goal"><strong>Mission Objective:</strong> ${escapeHtml(ch.vm2.goal)}</p>

                <div class="guidelines-box dos">
                  <h5>What to do (Best Practices)</h5>
                  <ul>${vm2Dos}</ul>
                </div>

                <div class="guidelines-box donts">
                  <h5>What NOT to do (Safety & Pitfalls)</h5>
                  <ul>${vm2Donts}</ul>
                </div>

                <div class="commands-section">
                  <h5>⚡ Blue Team Terminal Commands</h5>
                  ${vm2Commands}
                </div>

                <div class="downloads-section">
                  <h5>📂 Blue Team File Downloads</h5>
                  <div class="download-pills">
                    ${vm2Downloads}
                  </div>
                </div>
              </div>
            </div>
          </div>
        `;

        container.appendChild(card);
      });
    })
    .catch(err => {
      console.error('Failed to load challenges:', err);
      document.getElementById('challenges-container').innerHTML = '<p style="color: #ef4444;">Error loading challenge data.</p>';
    });
});

function copyCommand(btn, text) {
  navigator.clipboard.writeText(text).then(() => {
    const originalText = btn.textContent;
    btn.textContent = 'Copied!';
    btn.style.background = '#22c55e';
    btn.style.color = '#090d16';
    setTimeout(() => {
      btn.textContent = originalText;
      btn.style.background = '';
      btn.style.color = '';
    }, 2000);
  }).catch(err => {
    console.error('Failed to copy text: ', err);
  });
}

function escapeHtml(str) {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}

function escapeJs(str) {
  return str.replace(/\\/g, '\\\\').replace(/`/g, '\\`').replace(/\$/g, '\\\$');
}
