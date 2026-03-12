<script setup>
import { ref } from 'vue';
import { useAppStore } from '../stores/app';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';

const appStore = useAppStore();
const marketplaceFamilyId = ref('');
const offers = ref([]);
const offerForm = ref({ familyId: '', title: '', coinCost: '' });
const redeemForm = ref({ offerId: '' });

const loadOffers = () => appStore.runAction(async () => {
  const data = await appStore.request(`/api/marketplace/offers/${marketplaceFamilyId.value}`, { headers: appStore.authHeaders() });
  offers.value = data.offers || [];
}, 'Marketplace offers loaded.');

const createOffer = () => appStore.runAction(async () => {
  await appStore.request('/api/marketplace/offers', { 
    method: 'POST', 
    headers: appStore.authHeaders(), 
    body: JSON.stringify({ 
      familyId: Number(offerForm.value.familyId), 
      title: offerForm.value.title, 
      coinCost: Number(offerForm.value.coinCost) 
    }) 
  });
  marketplaceFamilyId.value = offerForm.value.familyId;
  await loadOffers();
}, 'Offer created.');

const redeemOffer = () => appStore.runAction(async () => {
  await appStore.request(`/api/marketplace/offers/${redeemForm.value.offerId}/redeem`, { 
    method: 'POST', 
    headers: appStore.authHeaders() 
  });
  if (marketplaceFamilyId.value) await loadOffers();
}, 'Offer redeemed.');
</script>

<template>
  <VCard title="CareCoins Marketplace">
    <div class="row">
      <VInput v-model="marketplaceFamilyId" type="number" label="Family ID" />
      <VButton type="secondary" @click="loadOffers">Load offers</VButton>
    </div>

    <ul v-if="offers.length > 0" class="offer-grid">
      <li v-for="o in offers" :key="o.id" class="offer-item">
        <div class="offer-id">#{{ o.id }}</div>
        <div class="offer-title">{{ o.title }}</div>
        <div class="offer-cost">{{ o.coin_cost }} cc</div>
        <div class="offer-status">{{ o.status }}</div>
      </li>
    </ul>

    <hr />

    <h3>Create New Offer</h3>
    <div class="grid three">
      <VInput v-model="offerForm.familyId" type="number" label="Family ID" />
      <VInput v-model="offerForm.title" label="Title" placeholder="Movie Night Choice" />
      <VInput v-model="offerForm.coinCost" type="number" label="Coin Cost" placeholder="200" />
    </div>
    <VButton type="primary" @click="createOffer" style="margin-top: 1rem;">Create offer</VButton>

    <hr />

    <h3>Redeem Offer</h3>
    <div class="row">
      <VInput v-model="redeemForm.offerId" type="number" label="Offer ID" placeholder="Offer # to redeem" />
      <VButton type="outline" @click="redeemOffer">Redeem offer</VButton>
    </div>
  </VCard>
</template>

<style scoped>
.offer-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 1rem;
  margin-top: 1.5rem;
}
.offer-item {
  display: flex;
  flex-direction: column;
  padding: 1.5rem;
  transition: transform 0.2s;
}
.offer-id {
  font-size: 0.8rem;
  color: var(--text-secondary);
  margin-bottom: 0.5rem;
}
.offer-title {
  font-weight: 600;
  color: #fff;
  font-size: 1.1rem;
  margin-bottom: 0.5rem;
  flex: 1;
}
.offer-cost {
  color: var(--accent-secondary);
  font-weight: 700;
  font-size: 1.25rem;
  margin-bottom: 0.5rem;
}
.offer-status {
  display: inline-block;
  align-self: flex-start;
  font-size: 0.75rem;
  text-transform: uppercase;
  background: rgba(255,255,255,0.1);
  padding: 2px 8px;
  border-radius: 4px;
}
</style>
