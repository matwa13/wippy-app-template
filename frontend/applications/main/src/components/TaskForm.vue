<script setup lang="ts">
import { ref, watch } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Checkbox from 'primevue/checkbox'
import Select from 'primevue/select'
import DatePicker from 'primevue/datepicker'
import Textarea from 'primevue/textarea'
import type { Task } from '../stores/tasks'

export interface TaskFormPayload {
  title: string
  done: boolean
  priority: number
  due_date: string | null
  notes: string
}

const props = defineProps<{
  initial: Task
  loading?: boolean
}>()

const emit = defineEmits<{
  submit: [payload: TaskFormPayload]
  cancel: []
}>()

const PRIORITY_OPTIONS = [
  { label: 'Low', value: 1 },
  { label: 'Medium', value: 2 },
  { label: 'High', value: 3 },
]

const title = ref('')
const done = ref(false)
const priority = ref(2)
const dueDate = ref<Date | null>(null)
const notes = ref('')

function parseDate(s: string | null | undefined): Date | null {
  if (!s) return null
  const [y, m, d] = s.split('-').map(Number)
  if (!y || !m || !d) return null
  return new Date(y, m - 1, d)
}

function formatDate(d: Date | null): string | null {
  if (!d) return null
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

watch(() => props.initial, (task) => {
  title.value = task.title
  done.value = task.done
  priority.value = task.priority ?? 2
  dueDate.value = parseDate(task.due_date)
  notes.value = task.notes ?? ''
}, { immediate: true })

function onSubmit() {
  const t = title.value.trim()
  if (!t) return
  emit('submit', {
    title: t,
    done: done.value,
    priority: priority.value,
    due_date: formatDate(dueDate.value),
    notes: notes.value.trim(),
  })
}
</script>

<template>
  <form
    class="flex flex-col gap-3"
    @submit.prevent="onSubmit"
  >
    <div class="flex items-center gap-2">
      <Checkbox
        v-model="done"
        binary
        input-id="task-done"
      />
      <label
        for="task-done"
        class="text-sm text-surface-700 dark:text-surface-300"
      >
        Mark as done
      </label>
    </div>

    <div>
      <label class="block mb-1 text-xs font-medium text-muted-color">Title</label>
      <InputText
        v-model="title"
        fluid
        autofocus
        :disabled="loading"
      />
    </div>

    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block mb-1 text-xs font-medium text-muted-color">Priority</label>
        <Select
          v-model="priority"
          :options="PRIORITY_OPTIONS"
          option-label="label"
          option-value="value"
          fluid
          :disabled="loading"
        />
      </div>
      <div>
        <label class="block mb-1 text-xs font-medium text-muted-color">Due date</label>
        <DatePicker
          v-model="dueDate"
          date-format="yy-mm-dd"
          fluid
          show-icon
          show-button-bar
          placeholder="No date"
          :disabled="loading"
        />
      </div>
    </div>

    <div>
      <label class="block mb-1 text-xs font-medium text-muted-color">Notes</label>
      <Textarea
        v-model="notes"
        rows="4"
        fluid
        auto-resize
        placeholder="Optional notes…"
        :disabled="loading"
      />
    </div>

    <div class="flex justify-end gap-2 mt-2">
      <Button
        type="button"
        label="Cancel"
        severity="secondary"
        text
        :disabled="loading"
        @click="emit('cancel')"
      />
      <Button
        type="submit"
        label="Save"
        :disabled="!title.trim() || loading"
        :loading="loading"
      />
    </div>
  </form>
</template>
