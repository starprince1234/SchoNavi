<script setup lang="ts">
import { useRouter } from 'vue-router'
import { Trash2 } from 'lucide-vue-next'
import StateView from '../components/StateView.vue'
import { useHistory } from '../stores/localStore'

const router = useRouter()
const historyStore = useHistory()
const historyItems = historyStore.history

function clearAll() {
  if (window.confirm('确定清空全部搜索历史吗？')) {
    historyStore.clear()
  }
}
</script>

<template>
  <section class="content-view">
    <div class="page-toolbar">
      <div>
        <p>本地历史</p>
        <h1>历史</h1>
      </div>
      <button v-if="historyItems.length" class="secondary-button" type="button" @click="clearAll">
        <Trash2 :size="17" />清空
      </button>
    </div>
    <StateView
      v-if="!historyItems.length"
      title="暂无搜索历史"
      message="完成一次推荐后，历史记录会自动保存在本机浏览器。"
      action-label="去搜索"
      @action="router.push('/home')"
    />
    <section v-else class="history-list">
      <article v-for="item in historyItems" :key="item.id" class="history-row">
        <button type="button" @click="router.push({ path: '/recommendation', query: { q: item.prompt } })">
          <strong>{{ item.prompt }}</strong>
          <span>{{ item.recommendation_count }} 位导师 · {{ item.summary }}</span>
        </button>
        <button class="icon-button" type="button" title="删除历史" @click="historyStore.remove(item.id)">
          <Trash2 :size="18" />
        </button>
      </article>
    </section>
  </section>
</template>
