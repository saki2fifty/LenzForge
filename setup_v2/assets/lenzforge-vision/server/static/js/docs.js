// LenzForge V2 - Documentation Viewer
class DocsViewer {
	constructor() {
		this.docs = [];
		this.currentDoc = null;
		this.categories = {};
	}

	async init() {
		await this.loadDocs();
		this.setupButton();
	}

	setupButton() {
		// Add docs button to header
		const header = document.querySelector('.header-content');
		if (header) {
			const docsBtn = document.createElement('button');
			docsBtn.className = 'docs-button';
			docsBtn.innerHTML = '📚 Docs';
			docsBtn.onclick = () => this.open();
			header.appendChild(docsBtn);
		}
	}

	async loadDocs() {
		try {
			const response = await fetch('/api/docs/list');
			const data = await response.json();
			this.categories = data.categories;
			this.docs = data.docs;
		} catch (error) {
			console.error('Failed to load docs:', error);
		}
	}

	open(docId = null) {
		// Create modal overlay
		const modal = document.createElement('div');
		modal.className = 'docs-modal';
		modal.innerHTML = `
			<div class="docs-container">
				<div class="docs-header">
					<h2>📚 Documentation</h2>
					<button class="docs-close" onclick="window.docsViewer.close()">✕</button>
				</div>
				<div class="docs-body">
					<div class="docs-sidebar">
						<div class="docs-search-box">
							<input type="search" id="docsSearch" placeholder="Search docs..." />
						</div>
						<div class="docs-categories" id="docsCategories"></div>
					</div>
					<div class="docs-content">
						<div id="docsContentArea">
							<div class="docs-welcome">
								<h1>Welcome to LenzForge Documentation</h1>
								<p>Select a topic from the sidebar to get started.</p>
							</div>
						</div>
					</div>
				</div>
			</div>
		`;

		document.body.appendChild(modal);
		this.renderSidebar();
		this.setupSearch();

		// Load specific doc if requested
		if (docId) {
			this.loadDoc(docId);
		}

		// Close on overlay click
		modal.addEventListener('click', (e) => {
			if (e.target === modal) {
				this.close();
			}
		});

		// Close on Escape key
		document.addEventListener('keydown', this.handleEscape);
	}

	close() {
		const modal = document.querySelector('.docs-modal');
		if (modal) {
			modal.remove();
		}
		document.removeEventListener('keydown', this.handleEscape);
	}

	handleEscape = (e) => {
		if (e.key === 'Escape') {
			this.close();
		}
	}

	renderSidebar() {
		const container = document.getElementById('docsCategories');
		if (!container) return;

		let html = '';
		for (const [category, docs] of Object.entries(this.categories)) {
			html += `
				<div class="docs-category">
					<h3>${category}</h3>
					<ul class="docs-list">
						${docs.map(doc => `
							<li>
								<a href="#" onclick="window.docsViewer.loadDoc('${doc.id}'); return false;">
									${doc.title}
								</a>
							</li>
						`).join('')}
					</ul>
				</div>
			`;
		}

		container.innerHTML = html;
	}

	setupSearch() {
		const searchInput = document.getElementById('docsSearch');
		if (!searchInput) return;

		let searchTimeout;
		searchInput.addEventListener('input', (e) => {
			clearTimeout(searchTimeout);
			searchTimeout = setTimeout(() => {
				this.search(e.target.value);
			}, 300);
		});
	}

	async search(query) {
		if (!query.trim()) {
			this.renderSidebar();
			return;
		}

		try {
			const response = await fetch(`/api/docs/search?q=${encodeURIComponent(query)}`);
			const data = await response.json();
			this.renderSearchResults(data.results);
		} catch (error) {
			console.error('Search failed:', error);
		}
	}

	renderSearchResults(results) {
		const container = document.getElementById('docsCategories');
		if (!container) return;

		if (results.length === 0) {
			container.innerHTML = '<div class="docs-no-results">No results found</div>';
			return;
		}

		let html = '<div class="docs-category"><h3>Search Results</h3><ul class="docs-list">';
		for (const result of results) {
			html += `
				<li>
					<a href="#" onclick="window.docsViewer.loadDoc('${result.id}'); return false;">
						${result.title}
					</a>
					<div class="docs-match-preview">
						${result.matches.slice(0, 2).map(m => `<div>${this.escapeHtml(m.substring(0, 80))}...</div>`).join('')}
					</div>
				</li>
			`;
		}
		html += '</ul></div>';
		container.innerHTML = html;
	}

	async loadDoc(docId) {
		try {
			const response = await fetch(`/api/docs/${docId}`);
			const doc = await response.json();
			this.currentDoc = doc;
			this.renderDoc(doc);
		} catch (error) {
			console.error('Failed to load doc:', error);
			this.renderError();
		}
	}

	renderDoc(doc) {
		const container = document.getElementById('docsContentArea');
		if (!container) return;

		// Convert markdown to HTML (simple conversion)
		const html = this.markdownToHtml(doc.content);

		container.innerHTML = `
			<div class="docs-article">
				<div class="docs-breadcrumb">
					${doc.category} / ${doc.title}
				</div>
				${html}
			</div>
		`;

		// Scroll to top
		container.scrollTop = 0;
	}

	renderError() {
		const container = document.getElementById('docsContentArea');
		if (!container) return;

		container.innerHTML = `
			<div class="docs-error">
				<h2>Error Loading Documentation</h2>
				<p>Failed to load the requested documentation. Please try again.</p>
			</div>
		`;
	}

	markdownToHtml(markdown) {
		let html = markdown;

		// Headers
		html = html.replace(/^### (.*$)/gim, '<h3>$1</h3>');
		html = html.replace(/^## (.*$)/gim, '<h2>$1</h2>');
		html = html.replace(/^# (.*$)/gim, '<h1>$1</h1>');

		// Bold
		html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');

		// Code blocks
		html = html.replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
			return `<pre><code class="language-${lang || 'text'}">${this.escapeHtml(code)}</code></pre>`;
		});

		// Inline code
		html = html.replace(/`([^`]+)`/g, '<code>$1</code>');

		// Lists
		html = html.replace(/^\* (.*)$/gim, '<li>$1</li>');
		html = html.replace(/^- (.*)$/gim, '<li>$1</li>');
		html = html.replace(/(<li>.*<\/li>)/s, '<ul>$1</ul>');

		// Paragraphs
		html = html.split('\n\n').map(para => {
			para = para.trim();
			if (!para) return '';
			if (para.startsWith('<')) return para;
			return `<p>${para}</p>`;
		}).join('\n');

		return html;
	}

	escapeHtml(text) {
		const div = document.createElement('div');
		div.textContent = text;
		return div.innerHTML;
	}
}

// Initialize docs viewer when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
	window.docsViewer = new DocsViewer();
	window.docsViewer.init();
});
