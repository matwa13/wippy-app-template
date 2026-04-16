import { defineStore } from 'pinia'
import { ref } from 'vue'

export interface Task {
  id: string
  title: string
  done: boolean
  notes?: string | null
  due_date?: string | null
  priority: number
  created_at: number
  updated_at: number
}

export const useTasksStore = defineStore('tasks', () => {
  const list = ref<Task[]>([])
  return { list }
}, {
  wippyPersist: {
    pick: ['list'],
  },
})
