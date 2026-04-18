import { defineStore } from 'pinia'
import { ref } from 'vue'

export interface TripSummary {
  id: string
  title: string
  destination: string
  start_date: string
  end_date: string
  status: 'planning' | 'ready' | 'partial' | 'failed'
  updated_at: number
}

export interface NodeState {
  status: 'pending' | 'running' | 'done' | 'failed'
  started_at?: number
  ended_at?: number
  iterations?: number
  error?: string
}

export interface WorkflowState {
  nodes: Record<string, NodeState>
}

export interface PlanJson {
  attractions?: Array<{
    name: string
    description: string
    typical_duration_hours: number
    constraints: string[]
  }>
  packing?: Array<{ category: string, items: string[] }>
  flights?: { google_flights_url: string, skyscanner_url: string }
  itinerary?: Array<{
    date: string
    attraction_name: string
    time_slot: string
    estimated_duration_hours: number
    description: string
    constraints: string[]
  }>
  warnings?: string[]
}

export interface TripDetail extends TripSummary {
  origin: string | null
  workflow_id: string | null
  workflow_state: WorkflowState | null
  plan_json: PlanJson | null
  tasks: Array<{
    id: string
    title: string
    done: boolean
    scheduled_at: string | null
    priority: number
  }>
}

export const useTripsStore = defineStore('trips', () => {
  const list = ref<TripSummary[]>([])
  return { list }
}, {
  wippyPersist: {
    pick: ['list'],
  },
})
