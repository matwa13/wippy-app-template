<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Icon } from '@iconify/vue'
import { useMutation } from '@tanstack/vue-query'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import DatePicker from 'primevue/datepicker'
import { useApi, useHost } from '../composables/useWippy'

const api = useApi()
const host = useHost()
const router = useRouter()

const destination = ref('')
const origin = ref('')
const startDate = ref<Date | null>(null)
const endDate = ref<Date | null>(null)

function format(d: Date | null): string | undefined {
  if (!d) return undefined
  const y = d.getFullYear(), m = String(d.getMonth() + 1).padStart(2, '0'), day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const mutation = useMutation({
  mutationFn: async () => {
    const body: Record<string, unknown> = {
      destination: destination.value.trim(),
      start_date: format(startDate.value),
      end_date: format(endDate.value),
    }
    const o = origin.value.trim()
    if (o) body.origin = o
    const { data } = await api.post('/api/v1/trips', body)
    if (!data.success) throw new Error(data.error || 'failed to create trip')
    return data as { trip_id: string, url: string }
  },
  onSuccess: (res) => router.push('/trips/' + res.trip_id),
  onError: (e: Error) => host.toast({ severity: 'error', summary: e.message }),
})

function submit() {
  if (!destination.value.trim() || !startDate.value || !endDate.value) return
  mutation.mutate()
}
</script>

<template>
  <div class="h-full flex flex-col">
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
      <h1 class="text-sm font-semibold text-surface-900 dark:text-surface-0">
        New Trip
      </h1>
    </div>
    <form
      class="px-5 py-5 grid grid-cols-2 gap-4 max-w-lg"
      @submit.prevent="submit"
    >
      <div class="col-span-2">
        <label class="block mb-1 text-xs font-medium text-muted-color">Destination</label>
        <InputText
          v-model="destination"
          fluid
          placeholder="Tokyo"
          :disabled="mutation.isPending.value"
        />
      </div>
      <div class="col-span-2">
        <label class="block mb-1 text-xs font-medium text-muted-color">Origin (optional)</label>
        <InputText
          v-model="origin"
          fluid
          placeholder="Berlin"
          :disabled="mutation.isPending.value"
        />
      </div>
      <div>
        <label class="block mb-1 text-xs font-medium text-muted-color">Start date</label>
        <DatePicker
          v-model="startDate"
          date-format="yy-mm-dd"
          :min-date="new Date()"
          fluid
          show-icon
        />
      </div>
      <div>
        <label class="block mb-1 text-xs font-medium text-muted-color">End date</label>
        <DatePicker
          v-model="endDate"
          date-format="yy-mm-dd"
          :min-date="startDate ?? new Date()"
          fluid
          show-icon
        />
      </div>
      <div class="col-span-2 flex justify-end">
        <Button
          type="submit"
          label="Plan Trip"
          :disabled="!destination.trim() || !startDate || !endDate || mutation.isPending.value"
          :loading="mutation.isPending.value"
        />
      </div>
    </form>
  </div>
</template>
