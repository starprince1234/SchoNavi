<script setup lang="ts">
import type { QueryUnderstanding } from '../types/api'
import FieldChips from './FieldChips.vue'

defineProps<{ understanding: QueryUnderstanding }>()
</script>

<template>
  <section class="query-panel">
    <h2>需求理解</h2>
    <div class="understanding-grid">
      <div>
        <span>研究方向</span>
        <FieldChips :fields="understanding.research_interests" />
        <p v-if="!understanding.research_interests.length">暂无明确方向</p>
      </div>
      <div>
        <span>地区偏好</span>
        <FieldChips :fields="understanding.preferred_locations" />
        <p v-if="!understanding.preferred_locations.length">不限地区</p>
      </div>
      <div>
        <span>院校偏好</span>
        <FieldChips :fields="understanding.preferred_universities" />
        <p v-if="!understanding.preferred_universities.length">不限院校</p>
      </div>
      <div>
        <span>申请阶段</span>
        <p>{{ understanding.degree_stage || '暂无明确阶段' }}</p>
      </div>
    </div>
    <p v-if="understanding.uncertainties.length" class="limitations">
      {{ understanding.uncertainties.join('；') }}
    </p>
  </section>
</template>

