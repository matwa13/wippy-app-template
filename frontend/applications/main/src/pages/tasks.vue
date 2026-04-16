<script setup lang="ts">
import { ref, computed, watch, onUnmounted } from 'vue'
import { Icon } from '@iconify/vue'
import { useQuery, useQueryClient, useMutation } from '@tanstack/vue-query'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Checkbox from 'primevue/checkbox'
import SelectButton from 'primevue/selectbutton'
import Select from 'primevue/select'
import DatePicker from 'primevue/datepicker'
import Textarea from 'primevue/textarea'
import { useApi, useHost, useWippy } from '../composables/useWippy'
import { useTasksStore } from '../stores/tasks'
import type { Task } from '../stores/tasks'

const api = useApi()
const host = useHost()
const wippy = useWippy()
const queryClient = useQueryClient()
const tasksStore = useTasksStore()

const TODAY = new Date().toISOString().slice(0, 10)

function priorityLabel(p: number) {
  return p === 3 ? 'High' : p === 1 ? 'Low' : 'Med'
}

function priorityClass(p: number) {
  return p === 3
    ? 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300'
    : p === 1
      ? 'bg-surface-100 text-surface-500 dark:bg-surface-700 dark:text-surface-400'
      : 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/40 dark:text-yellow-300'
}

const expandedNotes = ref<string[]>([])
function toggleNotes(id: string) {
  const idx = expandedNotes.value.indexOf(id)
  if (idx >= 0) expandedNotes.value.splice(idx, 1)
  else expandedNotes.value.push(id)
}

const TASKS_KEY = ['tasks'] as const

const filter = ref<'all' | 'open' | 'done'>('all')
const FILTER_OPTIONS = [
  { label: 'All', value: 'all' },
  { label: 'Open', value: 'open' },
  { label: 'Done', value: 'done' },
]

const { data: tasks, isPending, isError } = useQuery({
  queryKey: TASKS_KEY,
  queryFn: async () => {
    const { data } = await api.get('/api/v1/tasks')
    if (data.success) return (data.tasks || []) as Task[]
    return [] as Task[]
  },
  placeholderData: () => (tasksStore.list.length > 0 ? tasksStore.list : undefined),
})

watch(tasks, (val) => {
  if (val) tasksStore.list = val
})

const visibleTasks = computed(() => {
  const all = tasks.value ?? []
  if (filter.value === 'open') return all.filter(t => !t.done)
  if (filter.value === 'done') return all.filter(t => t.done)
  return all
})

const unbind = wippy.on('tasks:changed', () => {
  queryClient.invalidateQueries({ queryKey: TASKS_KEY })
})
onUnmounted(() => unbind?.())

const PRIORITY_OPTIONS = [
  { label: 'Low', value: 1 },
  { label: 'Medium', value: 2 },
  { label: 'High', value: 3 },
]

const newTitle = ref('')
const newPriority = ref(2)
const newDueDate = ref<Date | null>(null)
const newNotes = ref('')
const showMoreFields = ref(false)

function resetForm() {
  newTitle.value = ''
  newPriority.value = 2
  newDueDate.value = null
  newNotes.value = ''
  showMoreFields.value = false
}

function formatDate(d: Date | null): string | undefined {
  if (!d) return undefined
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const createMutation = useMutation({
  mutationFn: async () => {
    const body: Record<string, unknown> = { title: newTitle.value.trim() }
    if (newPriority.value !== 2) body.priority = newPriority.value
    const due = formatDate(newDueDate.value)
    if (due) body.due_date = due
    const notes = newNotes.value.trim()
    if (notes) body.notes = notes
    const { data } = await api.post('/api/v1/tasks', body)
    return data
  },
  onSuccess: () => {
    resetForm()
    queryClient.invalidateQueries({ queryKey: TASKS_KEY })
  },
  onError: () => {
    host.toast({ severity: 'error', summary: 'Failed to add task' })
  },
})

function addTask() {
  const t = newTitle.value.trim()
  if (!t) return
  createMutation.mutate()
}

const toggleMutation = useMutation({
  mutationFn: async (task: Task) => {
    await api.patch(`/api/v1/tasks/${task.id}`, { done: !task.done })
  },
  onSuccess: () => queryClient.invalidateQueries({ queryKey: TASKS_KEY }),
  onError: () => host.toast({ severity: 'error', summary: 'Failed to update task' }),
})

function toggleDone(task: Task) {
  toggleMutation.mutate(task)
}

const deleteMutation = useMutation({
  mutationFn: async (task: Task) => {
    await api.delete(`/api/v1/tasks/${task.id}`)
  },
  onSuccess: () => queryClient.invalidateQueries({ queryKey: TASKS_KEY }),
  onError: () => host.toast({ severity: 'error', summary: 'Failed to delete task' }),
})

function removeTask(task: Task) {
  deleteMutation.mutate(task)
}
</script>

<template>
  <div class="h-full flex flex-col">
    <div class="px-5 py-4 border-b border-surface-200 dark:border-surface-700 bg-surface-card shrink-0">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="flex items-center justify-center w-8 h-8 rounded-lg bg-primary">
            <Icon
              icon="tabler:checkbox"
              class="w-5 h-5 text-primary-contrast"
              aria-hidden="true"
            />
          </div>
          <div>
            <h1 class="text-sm font-semibold text-surface-900 dark:text-surface-0">
              Tasks
            </h1>
            <p class="text-[11px] text-surface-400">
              {{ (tasks ?? []).length }} total · {{ (tasks ?? []).filter(t => !t.done).length }} open
            </p>
          </div>
        </div>
        <SelectButton
          v-model="filter"
          :options="FILTER_OPTIONS"
          option-label="label"
          option-value="value"
          size="small"
          :allow-empty="false"
          aria-label="Task filter"
        />
      </div>
    </div>

    <div class="px-5 py-3 border-b border-surface-200 dark:border-surface-700 bg-surface-card shrink-0">
      <form @submit.prevent="addTask">
        <div class="flex gap-2">
          <InputText
            v-model="newTitle"
            placeholder="Add a task…"
            fluid
            :disabled="createMutation.isPending.value"
          />
          <Button
            type="button"
            text
            rounded
            size="small"
            class="!p-1.5 shrink-0"
            :aria-label="showMoreFields ? 'Hide details' : 'Show details'"
            @click="showMoreFields = !showMoreFields"
          >
            <template #icon>
              <Icon
                :icon="showMoreFields ? 'tabler:chevron-up' : 'tabler:dots'"
                class="w-4 h-4"
                aria-hidden="true"
              />
            </template>
          </Button>
          <Button
            type="submit"
            label="Add"
            size="small"
            :disabled="!newTitle.trim() || createMutation.isPending.value"
            :loading="createMutation.isPending.value"
          >
            <template #icon>
              <Icon
                icon="tabler:plus"
                class="w-4 h-4"
                aria-hidden="true"
              />
            </template>
          </Button>
        </div>
        <div
          v-if="showMoreFields"
          class="mt-3 grid grid-cols-2 gap-3"
        >
          <div>
            <label class="block mb-1 text-xs font-medium text-muted-color">Priority</label>
            <Select
              v-model="newPriority"
              :options="PRIORITY_OPTIONS"
              option-label="label"
              option-value="value"
              fluid
              size="small"
              aria-label="Priority"
            />
          </div>
          <div>
            <label class="block mb-1 text-xs font-medium text-muted-color">Due date</label>
            <DatePicker
              v-model="newDueDate"
              date-format="yy-mm-dd"
              :min-date="new Date()"
              fluid
              size="small"
              show-icon
              show-button-bar
              placeholder="No date"
              aria-label="Due date"
            />
          </div>
          <div class="col-span-2">
            <label class="block mb-1 text-xs font-medium text-muted-color">Notes</label>
            <Textarea
              v-model="newNotes"
              rows="2"
              fluid
              auto-resize
              placeholder="Optional notes…"
              aria-label="Notes"
            />
          </div>
        </div>
      </form>
    </div>

    <div class="flex-1 overflow-y-auto">
      <div
        v-if="isError"
        class="h-full flex items-center justify-center"
      >
        <div class="text-center">
          <Icon
            icon="tabler:alert-circle"
            class="w-10 h-10 text-red-400 mx-auto mb-2"
            aria-hidden="true"
          />
          <p class="text-sm text-surface-400 mb-3">
            Failed to load tasks
          </p>
          <Button
            label="Retry"
            size="small"
            @click="() => queryClient.invalidateQueries({ queryKey: TASKS_KEY })"
          />
        </div>
      </div>

      <ul
        v-else-if="visibleTasks.length > 0"
        class="divide-y divide-surface-200 dark:divide-surface-700"
      >
        <li
          v-for="task in visibleTasks"
          :key="task.id"
          class="group"
          :class="task.due_date && task.due_date < TODAY && !task.done
            ? 'bg-red-50/50 dark:bg-red-900/10'
            : ''"
        >
          <div class="flex items-center gap-3 px-5 py-3 hover:bg-surface-50 dark:hover:bg-surface-900/50">
            <Checkbox
              :model-value="task.done"
              binary
              :aria-label="task.done ? `Mark ${task.title} as open` : `Mark ${task.title} as done`"
              @update:model-value="toggleDone(task)"
            />
            <span
              class="flex-1 text-sm"
              :class="task.done
                ? 'line-through text-surface-400'
                : 'text-surface-900 dark:text-surface-0'"
            >
              {{ task.title }}
            </span>
            <span
              v-if="task.priority !== undefined && task.priority !== 2"
              class="text-[10px] font-medium px-1.5 py-0.5 rounded"
              :class="priorityClass(task.priority)"
            >
              {{ priorityLabel(task.priority) }}
            </span>
            <span
              v-if="task.due_date && !task.done"
              class="text-[10px] font-medium px-1.5 py-0.5 rounded"
              :class="task.due_date < TODAY
                ? 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300'
                : 'bg-surface-100 text-surface-500 dark:bg-surface-700 dark:text-surface-400'"
            >
              {{ task.due_date }}
            </span>
            <Button
              v-if="task.notes"
              text
              rounded
              class="!p-1.5"
              :aria-label="`${expandedNotes.includes(task.id) ? 'Hide' : 'Show'} notes`"
              @click="toggleNotes(task.id)"
            >
              <template #icon>
                <Icon
                  :icon="expandedNotes.includes(task.id) ? 'tabler:chevron-up' : 'tabler:notes'"
                  class="w-4 h-4 text-surface-400"
                  aria-hidden="true"
                />
              </template>
            </Button>
            <Button
              text
              rounded
              severity="danger"
              class="!p-1.5 opacity-0 group-hover:opacity-100 transition-opacity"
              :aria-label="`Delete ${task.title}`"
              @click="removeTask(task)"
            >
              <template #icon>
                <Icon
                  icon="tabler:trash"
                  class="w-4 h-4"
                  aria-hidden="true"
                />
              </template>
            </Button>
          </div>
          <div
            v-if="task.notes && expandedNotes.includes(task.id)"
            class="px-5 pb-3 ml-9 text-sm text-surface-500 dark:text-surface-400 whitespace-pre-wrap"
          >
            {{ task.notes }}
          </div>
        </li>
      </ul>

      <div
        v-else-if="!isPending"
        class="h-full flex items-center justify-center"
      >
        <div class="text-center">
          <Icon
            icon="tabler:checkbox"
            class="w-10 h-10 text-surface-300 dark:text-surface-600 mx-auto mb-2"
            aria-hidden="true"
          />
          <p class="text-sm text-surface-400">
            {{ filter === 'all' ? 'No tasks yet — add one above or ask the assistant.' : `No ${filter} tasks.` }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
