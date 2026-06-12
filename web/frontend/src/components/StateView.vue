<script setup lang="ts">
defineProps<{
  title: string
  message?: string
  actionLabel?: string
}>()

defineEmits<{ action: [] }>()
</script>

<template>
  <section class="state-view">
    <h2>{{ title }}</h2>
    <p v-if="message">{{ message }}</p>
    <button v-if="actionLabel" class="primary-button" type="button" @click="$emit('action')">
      {{ actionLabel }}
    </button>
  </section>
</template>

