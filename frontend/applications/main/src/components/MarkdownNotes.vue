<script setup lang="ts">
import { computed } from 'vue'
import MarkdownIt from 'markdown-it'
import sanitizeHtml from 'sanitize-html'

const props = defineProps<{ source: string | null | undefined }>()

const md = new MarkdownIt({
  html: false,
  breaks: true,
  linkify: true,
  typographer: false,
})

md.core.ruler.after('inline', 'task-lists', (state) => {
  const tokens = state.tokens
  for (let i = 0; i < tokens.length - 2; i++) {
    if (
      tokens[i].type !== 'list_item_open'
      || tokens[i + 1].type !== 'paragraph_open'
      || tokens[i + 2].type !== 'inline'
    ) continue

    const inline = tokens[i + 2]
    const match = /^\[([ xX])\]\s+/.exec(inline.content)
    if (!match) continue

    const checked = match[1].toLowerCase() === 'x'
    inline.content = inline.content.replace(/^\[[ xX]\]\s+/, '')
    if (inline.children) {
      for (const child of inline.children) {
        if (child.type === 'text') {
          child.content = child.content.replace(/^\[[ xX]\]\s+/, '')
          break
        }
      }
      const cb = new state.Token('html_inline', '', 0)
      cb.content = `<input type="checkbox" disabled${checked ? ' checked' : ''}> `
      inline.children.unshift(cb)
    }
    tokens[i].attrJoin('class', 'task-list-item')
  }
  return true
})

const renderedHtml = computed(() => {
  const src = props.source
  if (!src) return ''
  const raw = md.render(src)
  return sanitizeHtml(raw, {
    allowedTags: [
      'p', 'br', 'strong', 'em', 'b', 'i', 's', 'del', 'code',
      'ul', 'ol', 'li', 'blockquote', 'pre', 'hr',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'a', 'input',
    ],
    allowedAttributes: {
      a: ['href', 'title', 'target', 'rel'],
      li: ['class'],
      input: ['type', 'checked', 'disabled'],
      code: ['class'],
    },
    allowedSchemes: ['http', 'https', 'mailto'],
    transformTags: {
      a: sanitizeHtml.simpleTransform('a', {
        target: '_blank',
        rel: 'noopener noreferrer',
      }),
    },
  })
})
</script>

<template>
  <div
    v-if="renderedHtml"
    class="markdown-notes"
    v-html="renderedHtml"
  />
</template>

<style scoped>
.markdown-notes :deep(p) {
  margin-bottom: 0.5rem;
}
.markdown-notes :deep(p:last-child) {
  margin-bottom: 0;
}
.markdown-notes :deep(a) {
  color: var(--p-primary-color);
  text-decoration: underline;
  text-underline-offset: 2px;
}
.markdown-notes :deep(a:hover) {
  opacity: 0.8;
}
.markdown-notes :deep(strong),
.markdown-notes :deep(b) {
  font-weight: 600;
  color: var(--p-text-color);
}
.markdown-notes :deep(ul),
.markdown-notes :deep(ol) {
  margin: 0.25rem 0 0.5rem;
  padding-left: 1.25rem;
}
.markdown-notes :deep(ul) { list-style: disc; }
.markdown-notes :deep(ol) { list-style: decimal; }
.markdown-notes :deep(li) {
  margin-bottom: 0.125rem;
}
.markdown-notes :deep(li.task-list-item) {
  list-style: none;
  margin-left: -1.25rem;
}
.markdown-notes :deep(li.task-list-item input[type="checkbox"]) {
  margin-right: 0.375rem;
  vertical-align: middle;
  cursor: default;
  accent-color: var(--p-primary-color);
}
.markdown-notes :deep(code) {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.875em;
  padding: 0.125em 0.25em;
  border-radius: 0.25rem;
  background: var(--p-surface-100);
}
:global(.dark) .markdown-notes :deep(code) {
  background: var(--p-surface-800);
}
.markdown-notes :deep(blockquote) {
  border-left: 2px solid var(--p-surface-300);
  padding-left: 0.75rem;
  margin: 0.5rem 0;
  color: var(--p-text-muted-color);
}
.markdown-notes :deep(hr) {
  border: none;
  border-top: 1px solid var(--p-surface-200);
  margin: 0.75rem 0;
}
</style>
