<script setup lang="ts">
defineProps<{ fields: string[] }>()
</script>

<template>
  <div class="chip-row" v-if="fields.length">
    <span class="chip" v-for="field in fields" :key="field">{{ field }}</span>
  </div>
</template>

