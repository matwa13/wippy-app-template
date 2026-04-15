import { defineStore } from 'pinia'
import { ref } from 'vue'

export interface Task {
  id: string
  title: string
  done: boolean
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
