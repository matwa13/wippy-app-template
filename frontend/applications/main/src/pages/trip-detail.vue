<script setup lang="ts">
import { computed, onUnmounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon } from '@iconify/vue'
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import Button from 'primevue/button'
import { useApi, useWippy } from '../composables/useWippy'
import type { TripDetail, NodeState } from '../stores/trips'

const api = useApi()
const wippy = useWippy()
const route = useRoute()
const router = useRouter()
const queryClient = useQueryClient()

const tripId = computed(() => route.params.id as string)
const TRIP_KEY = computed(() => ['trip', tripId.value])

const { data: trip, isPending } = useQuery({
  queryKey: TRIP_KEY,
  queryFn: async () => {
    const { data } = await api.get('/api/v1/trips/' + tripId.value)
    if (!data.success) throw new Error(data.error || 'not found')
    return data.trip as TripDetail
  },
  refetchInterval: (q) => {
    const s = (q.state.data as TripDetail | undefined)?.status
    return s === 'planning' ? 2000 : false
  },
})

const unbind = wippy.on('trips:changed', (ev: { data?: { trip_id?: string } }) => {
  if (ev?.data?.trip_id === tripId.value) {
    queryClient.invalidateQueries({ queryKey: TRIP_KEY.value })
  }
})
onUnmounted(() => unbind?.())

const NODE_ORDER: Array<{ key: string, label: string }> = [
  { key: 'normalize_input',      label: 'Normalize input' },
  { key: 'attractions_research', label: 'Attractions research' },
  { key: 'packing_research',     label: 'Packing research' },
  { key: 'flights_linker',       label: 'Flights' },
  { key: 'itinerary_synthesize', label: 'Itinerary synthesize' },
  { key: 'build_task_payloads',  label: 'Build task payloads' },
  { key: 'persist_tasks',        label: 'Persist tasks' },
]

function nodeIcon(s: NodeState | undefined) {
  if (!s) return 'tabler:circle'
  if (s.status === 'done') return 'tabler:check'
  if (s.status === 'failed') return 'tabler:x'
  if (s.status === 'running') return 'tabler:loader-2'
  return 'tabler:circle'
}
function nodeIconClass(s: NodeState | undefined) {
  if (!s) return 'text-surface-400'
  if (s.status === 'done') return 'text-green-500'
  if (s.status === 'failed') return 'text-red-500'
  if (s.status === 'running') return 'text-primary animate-spin'
  return 'text-surface-400'
}

const panelOpen = ref(true)
</script>

<template>
  <div
    v-if="trip"
    class="h-full flex flex-col"
  >
    <div class="px-5 py-4 border-b border-surface-200 dark:border-surface-700 bg-surface-card shrink-0 flex items-center gap-3">
      <Button
        text
        rounded
        size="small"
        aria-label="Back"
        @click="router.push('/trips')"
      >
        <template #icon>
          <Icon
            icon="tabler:arrow-left"
            class="w-4 h-4"
          />
        </template>
      </Button>
      <div class="min-w-0 flex-1">
        <h1 class="text-sm font-semibold text-surface-900 dark:text-surface-0 truncate">
          {{ trip.title }}
        </h1>
        <p class="text-[11px] text-surface-400">
          {{ trip.start_date }} – {{ trip.end_date }}
        </p>
      </div>
      <span
        class="text-[10px] font-medium px-1.5 py-0.5 rounded"
        :class="{
          'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300': trip.status === 'ready',
          'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300': trip.status === 'failed',
          'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/40 dark:text-yellow-300': trip.status === 'partial',
          'bg-surface-100 text-surface-600 dark:bg-surface-700 dark:text-surface-300': trip.status === 'planning',
        }"
      >{{ trip.status }}</span>
    </div>

    <div class="flex-1 overflow-y-auto px-5 py-4 space-y-4">
      <section class="border border-surface-200 dark:border-surface-700 rounded-lg">
        <button
          class="w-full flex items-center justify-between px-4 py-2 text-sm font-medium"
          @click="panelOpen = !panelOpen"
        >
          <span class="text-surface-900 dark:text-surface-0">Workflow</span>
          <Icon
            :icon="panelOpen ? 'tabler:chevron-up' : 'tabler:chevron-down'"
            class="w-4 h-4"
          />
        </button>
        <div
          v-if="panelOpen"
          class="px-4 pb-3 space-y-1"
        >
          <div
            v-for="node in NODE_ORDER"
            :key="node.key"
            class="flex items-center gap-2 text-xs"
          >
            <Icon
              :icon="nodeIcon(trip.workflow_state?.nodes[node.key])"
              :class="nodeIconClass(trip.workflow_state?.nodes[node.key])"
              class="w-4 h-4"
            />
            <span class="flex-1 text-surface-400">{{ node.label }}</span>
            <span
              v-if="trip.workflow_state?.nodes[node.key]?.error"
              class="text-[10px] text-red-500 truncate max-w-xs"
              :title="trip.workflow_state.nodes[node.key].error"
            >{{ trip.workflow_state.nodes[node.key].error }}</span>
          </div>
        </div>
      </section>

      <section
        v-if="trip.plan_json?.warnings?.length"
        class="border border-yellow-300 dark:border-yellow-700 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg p-3"
      >
        <h2 class="text-xs font-semibold text-yellow-800 dark:text-yellow-200 mb-1">
          Warnings
        </h2>
        <ul class="text-xs text-yellow-700 dark:text-yellow-300 list-disc ml-4">
          <li
            v-for="(w, i) in trip.plan_json.warnings"
            :key="i"
          >
            {{ w }}
          </li>
        </ul>
      </section>

      <section v-if="trip.plan_json?.attractions?.length">
        <h2 class="text-sm font-semibold mb-2 text-surface-900 dark:text-surface-0">
          Attractions
        </h2>
        <ul class="grid grid-cols-1 md:grid-cols-2 gap-2">
          <li
            v-for="a in trip.plan_json.attractions"
            :key="a.name"
            class="border border-surface-200 dark:border-surface-700 rounded p-3"
          >
            <div class="text-sm font-medium text-surface-900 dark:text-surface-0">
              {{ a.name }}
            </div>
            <div class="text-xs text-surface-500 mt-1">
              {{ a.description }}
            </div>
            <div class="text-[10px] text-surface-400 mt-1">
              ~{{ a.typical_duration_hours }}h
            </div>
          </li>
        </ul>
      </section>

      <section v-if="trip.plan_json?.packing?.length">
        <h2 class="text-sm font-semibold mb-2 text-surface-900 dark:text-surface-0">
          Packing
        </h2>
        <div
          v-for="cat in trip.plan_json.packing"
          :key="cat.category"
          class="mb-2"
        >
          <div class="text-xs font-medium text-surface-900 dark:text-surface-0">
            {{ cat.category }}
          </div>
          <ul class="text-xs text-surface-600 dark:text-surface-400 ml-4 list-disc">
            <li
              v-for="i in cat.items"
              :key="i"
            >
              {{ i }}
            </li>
          </ul>
        </div>
      </section>

      <section
        v-if="trip.plan_json?.flights"
        class="flex gap-2"
      >
        <a
          :href="trip.plan_json.flights.google_flights_url"
          target="_blank"
          rel="noopener"
        >
          <Button
            label="Google Flights"
            size="small"
            severity="secondary"
          >
            <template #icon><Icon
              icon="tabler:plane"
              class="w-4 h-4"
            /></template>
          </Button>
        </a>
        <a
          :href="trip.plan_json.flights.skyscanner_url"
          target="_blank"
          rel="noopener"
        >
          <Button
            label="Skyscanner"
            size="small"
            severity="secondary"
          >
            <template #icon><Icon
              icon="tabler:plane"
              class="w-4 h-4"
            /></template>
          </Button>
        </a>
      </section>

      <section v-if="trip.plan_json?.itinerary?.length">
        <h2 class="text-sm font-semibold mb-2 text-surface-900 dark:text-surface-0">
          Itinerary
        </h2>
        <ol class="space-y-2">
          <li
            v-for="(item, i) in trip.plan_json.itinerary"
            :key="i"
            class="border border-surface-200 dark:border-surface-700 rounded p-3"
          >
            <div class="flex items-center justify-between">
              <div class="text-sm font-medium text-surface-900 dark:text-surface-0">
                {{ item.attraction_name }}
              </div>
              <div class="text-[10px] text-surface-400">
                {{ item.date }} · {{ item.time_slot }} · {{ item.estimated_duration_hours }}h
              </div>
            </div>
            <div class="text-xs text-surface-500 mt-1">
              {{ item.description }}
            </div>
          </li>
        </ol>
      </section>

      <section v-if="trip.tasks?.length">
        <h2 class="text-sm font-semibold mb-2 text-surface-900 dark:text-surface-0">
          Generated tasks
        </h2>
        <ul class="text-xs space-y-1">
          <li
            v-for="t in trip.tasks"
            :key="t.id"
            class="flex items-center gap-2"
          >
            <Icon
              :icon="t.done ? 'tabler:check' : 'tabler:square'"
              class="w-3 h-3 text-surface-900 dark:text-surface-0"
            />
            <span
              class="text-surface-900 dark:text-surface-0"
              :class="t.done ? 'line-through text-surface-400' : ''"
            >{{ t.title }}</span>
            <span
              v-if="t.scheduled_at"
              class="text-[10px] text-surface-400"
            >{{ t.scheduled_at }}</span>
          </li>
        </ul>
        <Button
          label="Open tasks"
          size="small"
          severity="secondary"
          class="mt-2"
          @click="router.push('/tasks')"
        >
          <template #icon>
            <Icon
              icon="tabler:external-link"
              class="w-3 h-3"
            />
          </template>
        </Button>
      </section>
    </div>
  </div>
  <div
    v-else-if="isPending"
    class="h-full flex items-center justify-center"
  >
    <Icon
      icon="tabler:loader-2"
      class="w-6 h-6 text-primary animate-spin"
    />
  </div>
</template>
