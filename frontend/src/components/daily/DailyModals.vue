<script setup>
import VCard from '../VCard.vue';
import VButton from '../VButton.vue';

const props = defineProps({
  showSchedule:       Boolean,
  scheduleHour:       String,
  scheduleMinute:     String,
  showRecurrence:     Boolean,
  recurrenceForm:     Object,
  showDelete:         Boolean,
  deleteTarget:       Object,
  showBounty:         Boolean,
  bountyForm:         Object,
  showAcceptBounty:   Boolean,
  acceptBountyTarget: Object,
  showAbsence:        Boolean,
  absenceForm:        Object,
  showAbsenceDetail:  Boolean,
  selectedAbsence:    Object,
  isSubmittingAbsence: Boolean,
  role:               String,
});

const emit = defineEmits([
  'update:scheduleHour', 'update:scheduleMinute',
  'update:recurrenceForm', 'update:bountyForm', 'update:absenceForm',
  'confirm-schedule', 'close-schedule',
  'confirm-recurrence', 'close-recurrence',
  'confirm-delete-single', 'confirm-delete-series', 'close-delete',
  'confirm-bounty', 'close-bounty',
  'confirm-accept-bounty', 'close-accept-bounty',
  'confirm-absence', 'close-absence',
  'remove-absence', 'close-absence-detail',
]);
</script>

<template>
  <!-- ── Schedule time ─────────────────────────────────────────── -->
  <div v-if="showSchedule" class="modal-overlay bs-overlay">
    <VCard title="Confirm Time" style="max-width: 320px; width: 100%;">
      <div class="sheet-handle-bar"></div>
      <div style="margin-bottom: 1.5rem;">
        <label style="display:block; margin-bottom: 0.75rem; color: var(--text-primary); font-size: 1.1rem; font-weight: 800;">Starting at…</label>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <select :value="scheduleHour" @change="emit('update:scheduleHour', $event.target.value)"
                  style="flex:1; padding:0.75rem; border-radius:var(--r-pill); font-size:1.2rem; background:var(--input-bg); color:var(--text-primary); border:1px solid var(--input-border); text-align:center; appearance:none; outline:none;">
            <option v-for="h in 24" :key="h-1" :value="String(h-1).padStart(2,'0')">{{ String(h-1).padStart(2,'0') }}</option>
          </select>
          <span style="font-size:1.5rem; color:var(--text-primary); font-weight:bold;">:</span>
          <select :value="scheduleMinute" @change="emit('update:scheduleMinute', $event.target.value)"
                  style="flex:1; padding:0.75rem; border-radius:var(--r-pill); font-size:1.2rem; background:var(--input-bg); color:var(--text-primary); border:1px solid var(--input-border); text-align:center; appearance:none; outline:none;">
            <option value="00">00</option>
            <option value="30">30</option>
          </select>
          <span style="font-size:0.9rem; font-weight:800; color:var(--text-secondary); min-width:2.5rem; text-align:center;">
            {{ Number(scheduleHour) < 12 ? 'AM' : 'PM' }}
          </span>
        </div>
      </div>
      <div style="display:flex; justify-content:flex-end; gap:1rem;">
        <VButton type="secondary" @click="emit('close-schedule')">Cancel</VButton>
        <VButton type="primary"   @click="emit('confirm-schedule')">Schedule</VButton>
      </div>
    </VCard>
  </div>

  <!-- ── Recurrence ────────────────────────────────────────────── -->
  <div v-if="showRecurrence" class="modal-overlay">
    <VCard title="Schedule Future Copies" style="max-width: 350px; width: 100%;">
      <p class="text-sm" style="color:var(--text-secondary); margin-bottom:1.5rem; line-height:1.4;">
        Repeat <strong>{{ recurrenceForm.title }}</strong> at this time into the future.
      </p>
      <div style="margin-bottom:1.2rem;">
        <label style="display:block; margin-bottom:0.5rem; color:var(--text-primary); font-size:0.95rem; font-weight:600;">Frequency:</label>
        <select :value="recurrenceForm.frequency"
                @change="emit('update:recurrenceForm', { ...recurrenceForm, frequency: $event.target.value })"
                style="width:100%; padding:0.75rem; border-radius:var(--r-pill); font-size:1rem; background:var(--input-bg); color:var(--text-primary); border:1px solid var(--input-border); outline:none;">
          <option value="daily">Every Day</option>
          <option value="weekdays">Every Working Day (Mon–Fri)</option>
          <option value="weekly">Every Week (same day)</option>
        </select>
      </div>
      <div style="margin-bottom:1.8rem;">
        <label style="display:block; margin-bottom:0.5rem; color:var(--text-primary); font-size:0.95rem; font-weight:600;">Until Date:</label>
        <input type="date" :value="recurrenceForm.untilDate"
               @change="emit('update:recurrenceForm', { ...recurrenceForm, untilDate: $event.target.value })"
               style="width:100%; padding:0.75rem; border-radius:var(--r-pill); font-size:1rem; background:var(--input-bg); color:var(--text-primary); border:1px solid var(--input-border); outline:none;" />
      </div>
      <div style="display:flex; justify-content:flex-end; gap:1rem;">
        <VButton type="secondary" @click="emit('close-recurrence')">Cancel</VButton>
        <VButton type="primary"   @click="emit('confirm-recurrence')">Create schedule</VButton>
      </div>
    </VCard>
  </div>

  <!-- ── Delete recurring ──────────────────────────────────────── -->
  <div v-if="showDelete" class="modal-overlay bs-overlay">
    <VCard title="Delete Recurring Activity" style="max-width: 350px; width: 100%;">
      <div class="sheet-handle-bar"></div>
      <p class="text-sm" style="color:var(--text-secondary); margin-bottom:1.5rem; line-height:1.4;">
        <strong>{{ deleteTarget?.title }}</strong> is a recurring activity. Delete just this one, or everything from here onward?
      </p>
      <div style="display:flex; flex-direction:column; gap:0.8rem;">
        <VButton type="primary" block @click="emit('confirm-delete-single')">Delete just this one</VButton>
        <VButton type="danger"  block @click="emit('confirm-delete-series')">Delete this and all future</VButton>
        <VButton type="secondary" block style="margin-top:0.2rem;" @click="emit('close-delete')">Cancel</VButton>
      </div>
    </VCard>
  </div>

  <!-- ── Offer bounty ──────────────────────────────────────────── -->
  <div v-if="showBounty" class="modal-overlay">
    <VCard title="Delegate Task" style="max-width: 350px; width: 100%;">
      <p class="text-sm" style="color:var(--text-secondary); margin-bottom:1.5rem; line-height:1.4;">
        Add a coin bounty to <strong>{{ bountyForm.title }}</strong>. If another caregiver takes it over, these coins transfer from your balance to them.
      </p>
      <div style="margin-bottom:1.8rem;">
        <label style="display:block; margin-bottom:0.5rem; color:var(--text-primary); font-size:0.95rem; font-weight:600;">Offer amount (cc):</label>
        <div style="display:flex; align-items:center; gap:0.5rem;">
          <span style="font-size:1.4rem;">🪙</span>
          <input type="number" :value="bountyForm.amount"
                 @input="emit('update:bountyForm', { ...bountyForm, amount: $event.target.value })"
                 placeholder="e.g. 50" min="1"
                 style="width:100%; padding:0.75rem; border-radius:var(--r-pill); font-size:1.1rem; font-weight:800; background:var(--input-bg); color:var(--text-primary); border:1px solid var(--input-border); outline:none;" />
        </div>
      </div>
      <div style="display:flex; justify-content:flex-end; gap:1rem;">
        <VButton type="secondary" @click="emit('close-bounty')">Nevermind</VButton>
        <VButton type="primary"   @click="emit('confirm-bounty')">Offer Bounty</VButton>
      </div>
    </VCard>
  </div>

  <!-- ── Accept bounty ─────────────────────────────────────────── -->
  <div v-if="showAcceptBounty" class="modal-overlay">
    <VCard title="Claim task" style="max-width: 350px; width: 100%;">
      <p class="text-sm" style="color:var(--text-secondary); margin-bottom:1.5rem; line-height:1.4;">
        Take over <strong>{{ acceptBountyTarget?.title }}</strong> and earn
        <strong>🪙 {{ acceptBountyTarget?.bounty_amount }}cc</strong>. Coins transfer from the original caregiver to you immediately.
      </p>
      <div style="display:flex; justify-content:flex-end; gap:1rem;">
        <VButton type="secondary" @click="emit('close-accept-bounty')">Cancel</VButton>
        <VButton type="primary"   @click="emit('confirm-accept-bounty')">Claim task</VButton>
      </div>
    </VCard>
  </div>

  <!-- ── Log absence ───────────────────────────────────────────── -->
  <div v-if="showAbsence" class="modal-overlay">
    <VCard title="Log Time Off" style="max-width: 400px; width: 100%;">
      <p class="text-sm" style="color:var(--text-secondary); margin-bottom:1.5rem;">
        Record when you'll be unavailable. Coins for tasks during this time will be fairly distributed to caregivers who cover for you.
      </p>
      <div style="margin-bottom:1rem;">
        <label class="modal-label">Title (e.g., Business Trip)</label>
        <input type="text" :value="absenceForm.title"
               @input="emit('update:absenceForm', { ...absenceForm, title: $event.target.value })"
               class="modal-input" placeholder="Enter reason…" />
      </div>
      <div style="display:flex; flex-direction:column; gap:1rem; margin-bottom:1.8rem;">
        <div>
          <label class="modal-label">Start</label>
          <div style="display:flex; gap:0.5rem;">
            <input type="date" :value="absenceForm.startDate"
                   @change="emit('update:absenceForm', { ...absenceForm, startDate: $event.target.value })"
                   class="modal-input" style="flex:1;" />
            <input type="time" :value="absenceForm.startTime"
                   @change="emit('update:absenceForm', { ...absenceForm, startTime: $event.target.value })"
                   class="modal-input" style="flex:0 0 auto; width:7rem;" />
          </div>
        </div>
        <div>
          <label class="modal-label">End</label>
          <div style="display:flex; gap:0.5rem;">
            <input type="date" :value="absenceForm.endDate"
                   @change="emit('update:absenceForm', { ...absenceForm, endDate: $event.target.value })"
                   class="modal-input" style="flex:1;" />
            <input type="time" :value="absenceForm.endTime"
                   @change="emit('update:absenceForm', { ...absenceForm, endTime: $event.target.value })"
                   class="modal-input" style="flex:0 0 auto; width:7rem;" />
          </div>
        </div>
      </div>
      <div style="display:flex; justify-content:flex-end; gap:1rem;">
        <VButton type="secondary" @click="emit('close-absence')" :disabled="isSubmittingAbsence">Cancel</VButton>
        <VButton type="primary"   @click="emit('confirm-absence')" :disabled="isSubmittingAbsence">
          {{ isSubmittingAbsence ? 'Logging…' : 'Log Absence' }}
        </VButton>
      </div>
    </VCard>
  </div>

  <!-- ── Absence detail ────────────────────────────────────────── -->
  <div v-if="showAbsenceDetail" class="modal-overlay">
    <VCard title="Absence Details" style="max-width: 350px; width: 100%;">
      <div style="margin-bottom:1.5rem;">
        <div style="font-size:1.1rem; font-weight:800; margin-bottom:0.5rem; color:var(--primary);">
          {{ selectedAbsence?.title }}
        </div>
        <div class="text-sm" style="color:var(--text-secondary); margin-bottom:1rem;">
          Caregiver: <strong>{{ selectedAbsence?.user_alias || selectedAbsence?.user_name }}</strong>
        </div>
        <div style="background:var(--bg); padding:0.8rem; border-radius:var(--r-md); border:1px solid var(--border);">
          <div class="text-xs" style="text-transform:uppercase; color:var(--text-secondary); margin-bottom:0.4rem;">Timeframe</div>
          <div style="font-weight:600; font-size:0.9rem;">
            {{ new Date(selectedAbsence?.start_time).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) }}
            <br/>to<br/>
            {{ new Date(selectedAbsence?.end_time).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) }}
          </div>
        </div>
      </div>
      <div style="display:flex; flex-direction:column; gap:0.8rem;">
        <VButton v-if="selectedAbsence?.user_id == role || role === 'caregiver'"
                 type="danger" block @click="emit('remove-absence')">Remove Absence</VButton>
        <VButton type="secondary" block @click="emit('close-absence-detail')">Close</VButton>
      </div>
    </VCard>
  </div>
</template>

<style scoped>
.modal-overlay { z-index: 10000 !important; }
.modal-label { display: block; margin-bottom: 0.4rem; color: var(--text-primary); font-size: 0.9rem; font-weight: 600; }
.modal-input { width: 100%; padding: 0.75rem; border-radius: var(--r-pill); font-size: 1rem; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--input-border); outline: none; box-sizing: border-box; }
.sheet-handle-bar { display: none; }
@media (max-width: 768px) {
  .bs-overlay { align-items: flex-end !important; padding: 0 !important; }
  .bs-overlay :deep(.v-card) { width: 100% !important; max-width: 100% !important; border-radius: 20px 20px 0 0 !important; padding-bottom: env(safe-area-inset-bottom, 0px) !important; animation: sheet-slide-up 0.22s ease-out; }
  .sheet-handle-bar { display: block; width: 36px; height: 4px; background: var(--border); border-radius: 999px; margin: 0 auto 1.25rem; }
}
@keyframes sheet-slide-up { from { transform: translateY(100%); } to { transform: translateY(0); } }
</style>
