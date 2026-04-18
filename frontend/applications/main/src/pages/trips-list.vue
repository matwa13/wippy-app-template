<script setup lang="ts">
import { ref, computed, onUnmounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Icon } from '@iconify/vue'
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import Button from 'primevue/button'
import SelectButton from 'primevue/selectbutton'
import { useApi, useWippy } from '../composables/useWippy'
import { useTripsStore, type TripSummary } from '../stores/trips'

const api = useApi()
const wippy = useWippy()
const router = useRouter()
const queryClient = useQueryClient()
const tripsStore = useTripsStore()

const TRIPS_KEY = ['trips'] as const

const filter = ref<'all' | 'planning' | 'ready' | 'partial' | 'failed'>('all')
const FILTER_OPTIONS = [
  { label: 'All', value: 'all' },
  { label: 'Planning', value: 'planning' },
  { label: 'Ready', value: 'ready' },
  { label: 'Partial', value: 'partial' },
  { label: 'Failed', value: 'failed' },
]

const { data: trips, isPending } = useQuery({
  queryKey: TRIPS_KEY,
  queryFn: async () => {
    const { data } = await api.get('/api/v1/trips')
    return data.success ? (data.trips || []) as TripSummary[] : []
  },
  placeholderData: () => (tripsStore.list.length > 0 ? tripsStore.list : undefined),
})

watch(trips, (val) => {
  if (val) tripsStore.list = val
})

const visible = computed(() => {
  const all = trips.value ?? []
  if (filter.value === 'all') return all
  return all.filter(t => t.status === filter.value)
})

const unbind = wippy.on('trips:changed', () => {
  queryClient.invalidateQueries({ queryKey: TRIPS_KEY })
})
onUnmounted(() => unbind?.())

function statusClass(s: string) {
  return s === 'ready'
    ? 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300'
    : s === 'failed'
      ? 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300'
      : s === 'partial'
        ? 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/40 dark:text-yellow-300'
        : 'bg-surface-100 text-surface-600 dark:bg-surface-700 dark:text-surface-300'
}
</script>

<template>
  <div class="h-full flex flex-col">
    <div class="px-5 py-4 border-b border-surface-200 dark:border-surface-700 bg-surface-card shrink-0 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="flex items-center justify-center w-8 h-8 rounded-lg bg-primary">
          <Icon icon="tabler:plane" class="w-5 h-5 text-primary-contrast" aria-hidden="true" />
        </div>
        <div>
          <h1 class="text-sm font-semibold text-surface-900 dark:text-surface-0">Trips</h1>
          <p class="text-[11px] text-surface-400">{{ (trips ?? []).length }} total</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <SelectButton v-model="filter" :options="FILTER_OPTIONS" option-label="label" option-value="value" size="small" :allow-empty="false" />
        <Button label="New Trip" size="small" @click="router.push('/trips/create')">
          <template #icon><Icon icon="tabler:plus" class="w-4 h-4" /></template>
        </Button>
      </div>
    </div>
    <div class="flex-1 overflow-y-auto">
      <ul v-if="visible.length > 0" class="divide-y divide-surface-200 dark:divide-surface-700">
        <li v-for="t in visible" :key="t.id" class="px-5 py-3 hover:bg-surface-50 dark:hover:bg-surface-900/50 cursor-pointer" @click="router.push('/trips/' + t.id)">
          <div class="flex items-center justify-between gap-3">
            <div class="min-w-0">
              <div class="text-sm font-medium text-surface-900 dark:text-surface-0 truncate">{{ t.title }}</div>
              <div class="text-[11px] text-surface-400">{{ t.start_date }} – {{ t.end_date }}</div>
            </div>
            <span class="text-[10px] font-medium px-1.5 py-0.5 rounded shrink-0" :class="statusClass(t.status)">{{ t.status }}</span>
          </div>
        </li>
      </ul>
      <div v-else-if="!isPending" class="h-full flex items-center justify-center">
        <div class="text-center">
          <Icon icon="tabler:plane" class="w-10 h-10 text-surface-300 dark:text-surface-600 mx-auto mb-2" aria-hidden="true" />
          <p class="text-sm text-surface-400">No trips yet — create one or ask the assistant.</p>
        </div>
      </div>
    </div>
  </div>
</template>
