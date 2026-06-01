<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { ArrowRight, Sparkles, Coins, Calendar, ShoppingBag, CheckCircle2, ShieldCheck, TrendingUp, Award } from 'lucide-vue-next';

const router = useRouter();

// Interactive Widget State
const activeTab = ref('caregiver'); // 'caregiver' or 'marketplace'

const toggleTab = (tab) => {
  activeTab.value = tab;
};
</script>

<template>
  <div class="landing-page">
    <!-- Visual Gradient Blobs in Background -->
    <div class="bg-blob blob-1"></div>
    <div class="bg-blob blob-2"></div>
    <div class="bg-blob blob-3"></div>

    <!-- Hero Section -->
    <section class="hero-section">
      <div class="hero-container">
        <div class="badge-pill">
          <Sparkles class="icon-sparkle" :size="14" />
          <span>The Modern Family Economy</span>
        </div>
        <h1 class="hero-title">
          Inspire Motivation.<br />
          <span class="gradient-text">Empower Responsibility.</span>
        </h1>
        <p class="hero-subtitle">
          CareCoins turns family care coordination into a positive, rewarding experience. Define care tasks, schedule daily routines, and reward family caregivers for their contributions with coin payouts out of a monthly budget.
        </p>
        <div class="hero-ctas">
          <button class="btn btn-primary" @click="router.push('/login')">
            Get Started Free
            <ArrowRight :size="16" />
          </button>
          <button class="btn btn-secondary" @click="router.push('/login')">
            Sign In
          </button>
        </div>
      </div>
    </section>

    <!-- The Product Flow Flywheel -->
    <section class="features-section">
      <h2 class="section-title">The CareCoins Flywheel</h2>
      <p class="section-subtitle">How families build healthy habits together, step by step.</p>
      
      <div class="features-grid">
        <div class="feature-card">
          <div class="icon-wrapper primary-soft">
            <Coins class="icon color-primary" :size="24" />
          </div>
          <h3>1. Define Incentives</h3>
          <p>Create templates for care and household tasks. Assign custom coin values and set role-based requirements.</p>
        </div>

        <div class="feature-card">
          <div class="icon-wrapper success-soft">
            <Calendar class="icon color-success" :size="24" />
          </div>
          <h3>2. Schedule Daily Chores</h3>
          <p>Drag and drop tasks onto a collaborative timeline. Set up recurring routines and coordinate delegation.</p>
        </div>

        <div class="feature-card">
          <div class="icon-wrapper warning-soft">
            <CheckCircle2 class="icon color-warning" :size="24" />
          </div>
          <h3>3. Complete & Validate</h3>
          <p>Members complete tasks and check them off. Caregivers validate with a single tap, instant coin payout!</p>
        </div>

        <div class="feature-card">
          <div class="icon-wrapper danger-soft">
            <ShoppingBag class="icon color-danger" :size="24" />
          </div>
          <h3>4. Redeem Rewards</h3>
          <p>Accumulated coins can be exchanged for customizable rewards in your family's personal marketplace.</p>
        </div>
      </div>
    </section>

    <!-- Interactive Live Simulation Section -->
    <section class="demo-section">
      <div class="demo-header">
        <h2 class="section-title">Experience the Platform</h2>
        <p class="section-subtitle">See how CareCoins adapts to both caregivers and family members in real-time.</p>
      </div>

      <div class="demo-container">
        <!-- Interactive Tabs -->
        <div class="demo-tabs">
          <button 
            :class="['tab-btn', { active: activeTab === 'caregiver' }]" 
            @click="toggleTab('caregiver')"
          >
            <ShieldCheck :size="16" />
            Family Dashboard
          </button>
          <button 
            :class="['tab-btn', { active: activeTab === 'marketplace' }]" 
            @click="toggleTab('marketplace')"
          >
            <ShoppingBag :size="16" />
            Activities & Marketplace
          </button>
        </div>

        <!-- Interactive Screen -->
        <div class="demo-screen glassmorphic">
          <!-- Caregiver Screen (aligned with real Family Hub dashboard) -->
          <div v-if="activeTab === 'caregiver'" class="screen-content fade-in">
            <!-- Simulated Title Section -->
            <div class="sim-title-row">
               <h3 class="sim-hub-title">Family Hub</h3>
               <p class="sim-hub-subtitle">
                 Good morning, Mama! Your family has earned <strong class="color-dark">460 cc</strong> today. <strong class="color-dark">2 tasks</strong> are waiting for validation.
               </p>
            </div>

            <!-- Simulated Main Dashboard Grid -->
            <div class="sim-dashboard-grid">
               
               <!-- LEFT COLUMN (Members Grid + KPI Grid) -->
               <div class="sim-left-col">
                  <div class="sim-section-header">
                     <span class="sim-section-title">Active Family Members</span>
                  </div>

                  <!-- Members Cards Grid -->
                  <div class="sim-members-grid">
                     <!-- Caregivers / Members -->
                     <div class="sim-member-card color-0" title="Caregiver User">
                       <div class="sim-member-avatar">👩🏽</div>
                       <div class="sim-member-name">Mama (Caregiver)</div>
                       <div class="sim-member-coins text-color-0">● 120 cc</div>
                     </div>
                     <div class="sim-member-card color-1" title="Caregiver User">
                       <div class="sim-member-avatar">👨🏽</div>
                       <div class="sim-member-name">Papa (Caregiver)</div>
                       <div class="sim-member-coins text-color-1">● 340 cc</div>
                     </div>
                     <!-- Objects of Care (Dependents) -->
                     <div class="sim-member-card color-2" title="Object of Care / Dependent">
                       <div class="sim-member-avatar">👶🏽</div>
                       <div class="sim-member-name">Leo (Dependent)</div>
                       <div class="sim-member-coins text-color-2">● 80 cc Limit</div>
                     </div>
                     <div class="sim-member-card color-3" title="Object of Care / Dependent">
                       <div class="sim-member-avatar">👧🏽</div>
                       <div class="sim-member-name">Sofia (Dependent)</div>
                       <div class="sim-member-coins text-color-3">● 160 cc Limit</div>
                     </div>
                  </div>

                  <!-- KPI Cards Grid -->
                  <div class="sim-kpi-grid">
                     <!-- KPI 1 -->
                     <div class="sim-kpi-card">
                       <div class="sim-kpi-top">
                         <span class="sim-kpi-label">Family Balance</span>
                       </div>
                       <div class="sim-kpi-val-row">
                         <span class="sim-kpi-value color-primary">460</span>
                         <span class="sim-kpi-unit">cc</span>
                       </div>
                       <div class="sim-kpi-subtitle">across 4 members</div>
                     </div>
                     <!-- KPI 2 -->
                     <div class="sim-kpi-card">
                       <div class="sim-kpi-top">
                         <span class="sim-kpi-label">Tasks Today</span>
                       </div>
                       <div class="sim-kpi-val-row">
                         <span class="sim-kpi-value color-success">2/5</span>
                       </div>
                       <div class="sim-kpi-subtitle">2 awaiting validation</div>
                       <div class="sim-kpi-progress">
                         <div class="sim-kpi-progress-fill bg-success" style="width: 40%;"></div>
                       </div>
                     </div>
                     <!-- KPI 3 -->
                     <div class="sim-kpi-card">
                       <div class="sim-kpi-top">
                         <span class="sim-kpi-label">Open Bounties</span>
                       </div>
                       <div class="sim-kpi-val-row">
                         <span class="sim-kpi-value color-warning">1</span>
                       </div>
                       <div class="sim-kpi-subtitle">15 cc up for grabs</div>
                     </div>
                     <!-- KPI 4 -->
                     <div class="sim-kpi-card">
                       <div class="sim-kpi-top">
                         <span class="sim-kpi-label">Recent Activity</span>
                       </div>
                       <div class="sim-kpi-val-row">
                         <span class="sim-kpi-value color-ink">3</span>
                       </div>
                       <div class="sim-kpi-subtitle">completed recently</div>
                     </div>
                  </div>
               </div>

               <!-- RIGHT COLUMN (Recent Activity Feed) -->
               <div class="sim-right-col">
                  <div class="sim-activity-container">
                     <h3 class="sim-activity-title">Recent Activity</h3>
                     <div class="sim-activity-list">
                        <div class="sim-activity-item">
                           <div class="sim-act-icon bg-blue-soft text-blue">✓</div>
                           <div class="sim-act-details">
                              <div class="sim-act-desc">Mama completed <strong>Clean Room (Sofia)</strong></div>
                              <div class="sim-act-footer">
                                 <span class="sim-act-time">2 mins ago</span>
                                 <span class="sim-act-amount color-success">+20 cc</span>
                              </div>
                           </div>
                        </div>
                        <div class="sim-activity-item">
                           <div class="sim-act-icon bg-blue-soft text-blue">✓</div>
                           <div class="sim-act-details">
                              <div class="sim-act-desc">Papa completed <strong>Feed Pet (Fido)</strong></div>
                              <div class="sim-act-footer">
                                 <span class="sim-act-time">1 hour ago</span>
                                 <span class="sim-act-amount color-success">+10 cc</span>
                              </div>
                           </div>
                        </div>
                        <div class="sim-activity-item">
                           <div class="sim-act-icon bg-red-soft text-red">🛍️</div>
                           <div class="sim-act-details">
                              <div class="sim-act-desc">Mama redeemed <strong>Coffee Treat</strong></div>
                              <div class="sim-act-footer">
                                 <span class="sim-act-time">3 hours ago</span>
                                 <span class="sim-act-amount color-danger">-30 cc</span>
                              </div>
                           </div>
                        </div>
                     </div>
                  </div>
               </div>

            </div>
          </div>

          <!-- Marketplace & Chores Screen -->
          <div v-if="activeTab === 'marketplace'" class="screen-content fade-in">
            <div class="screen-header">
              <div>
                <span class="screen-badge bg-green-badge">MARKETPLACE & BUDGET</span>
                <h3 class="screen-title">Activities & Rewards Store</h3>
              </div>
              <div class="coin-display">
                <span class="coin-icon">★</span>
                <strong>460</strong>
                <span class="cc-lbl">Family Pool</span>
              </div>
            </div>

            <div class="screen-grid">
              <!-- Available Activity Templates -->
              <div class="widget-card">
                <h4>Task Templates Library</h4>
                <div class="widget-list">
                  <div class="list-item">
                    <div class="mock-reward-icon bg-blue">📚</div>
                    <div class="item-info">
                      <span class="name">Do Homework</span>
                      <span class="sub">Category: Care | Duration: 60m</span>
                    </div>
                    <span class="badge highlight">+15 cc</span>
                  </div>
                  <div class="list-item">
                    <div class="mock-reward-icon bg-green">🌱</div>
                    <div class="item-info">
                      <span class="name">Walk the Dog</span>
                      <span class="sub">Category: Household | Duration: 30m</span>
                    </div>
                    <span class="badge highlight">+10 cc</span>
                  </div>
                </div>
              </div>

              <!-- Rewards Store preview -->
              <div class="widget-card">
                <h4>Marketplace Rewards Catalog</h4>
                <div class="widget-list">
                  <div class="list-item reward-item">
                    <div class="mock-reward-icon bg-warning">🎮</div>
                    <div class="item-info">
                      <span class="name">1 Hour Video Games</span>
                      <span class="sub">Cost: 50cc | Available Limit: 3</span>
                    </div>
                    <button class="btn-action redeem-btn">Redeem</button>
                  </div>
                  <div class="list-item reward-item">
                    <div class="mock-reward-icon bg-danger">🍦</div>
                    <div class="item-info">
                      <span class="name">Ice Cream Treat</span>
                      <span class="sub">Cost: 30cc | Active Reward</span>
                    </div>
                    <button class="btn-action redeem-btn">Redeem</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Why CareCoins Analytics and Safety Section -->
    <section class="why-section">
      <div class="why-grid">
        <div class="why-text">
          <span class="screen-badge">INSIGHTFUL & ACCOUNTABLE</span>
          <h2>Why families love CareCoins</h2>
          <p>
            Traditional chore charts are easily forgotten, lack real-time positive feedback, and fail to teach actual budgeting principles. CareCoins digitizes task organization and adds double-entry ledger security to guarantee that accomplishments lead directly to customizable incentives.
          </p>
          <div class="why-perks">
            <div class="perk-row">
              <TrendingUp :size="20" class="perk-icon color-primary" />
              <div>
                <strong>Advanced ECharts Analytics</strong>
                <p>Track lifetime wealth, categorical breakdowns, and task completion percentages with rich data visualizers.</p>
              </div>
            </div>
            <div class="perk-row">
              <ShieldCheck :size="20" class="perk-icon color-success" />
              <div>
                <strong>Strict Role Management</strong>
                <p>Prevent database manipulation with Firebase authorization. Admins have strict oversight over payouts and budget limits.</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Simulated Ledger Visual Card -->
        <div class="why-visual glassmorphic">
          <div class="visual-header">
            <h4>Recent Transactions Ledger</h4>
            <span class="ledger-lock">SECURED LOGS</span>
          </div>
          <div class="ledger-list">
            <div class="ledger-row">
              <span class="l-date">Today</span>
              <span class="l-name">Mama (Caregiver)</span>
              <span class="l-desc">Redeemed: Coffee Treat</span>
              <span class="l-amount negative">-30 cc</span>
            </div>
            <div class="ledger-row">
              <span class="l-date">Today</span>
              <span class="l-name">Papa (Caregiver)</span>
              <span class="l-desc">Completed: Feed Pet (Fido)</span>
              <span class="l-amount positive">+10 cc</span>
            </div>
            <div class="ledger-row">
              <span class="l-date">Yesterday</span>
              <span class="l-name">Mama (Caregiver)</span>
              <span class="l-desc">Completed: Clean Room (Sofia)</span>
              <span class="l-amount positive">+20 cc</span>
            </div>
            <div class="ledger-row">
              <span class="l-date">Yesterday</span>
              <span class="l-name">System</span>
              <span class="l-desc">Initial Budget Allocation</span>
              <span class="l-amount positive">+500 cc</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Bottom Call to Action Section -->
    <section class="cta-section">
      <div class="cta-container glassmorphic">
        <h2>Ready to build a healthy family economy?</h2>
        <p>Join thousands of parents and caregivers using CareCoins to delegate responsibility and celebrate family success.</p>
        <button class="btn btn-primary btn-lg" @click="router.push('/login')">
          Get Started For Free
          <ArrowRight :size="18" />
        </button>
      </div>
    </section>

    <!-- Footer -->
    <footer class="landing-footer">
      <div class="footer-container">
        <div class="footer-logo">
          <strong>CareCoins</strong>
          <span>© 2026. All rights reserved.</span>
        </div>
        <div class="footer-links">
          <a href="#" @click.prevent="router.push('/login')">Log In</a>
          <a href="#" @click.prevent="router.push('/login')">Register</a>
        </div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
/* -------------------
   Landing View Styles
------------------- */
.landing-page {
  position: relative;
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 40px 20px;
  box-sizing: border-box;
  font-family: var(--font-family);
  overflow: visible;
}

/* Background Soft Glow Blobs */
.bg-blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(120px);
  z-index: -1;
  opacity: 0.15;
  pointer-events: none;
}
.blob-1 {
  top: -100px;
  left: 10%;
  width: 400px;
  height: 400px;
  background: var(--primary);
}
.blob-2 {
  top: 500px;
  right: 5%;
  width: 350px;
  height: 350px;
  background: var(--success);
}
.blob-3 {
  bottom: 10%;
  left: -50px;
  width: 500px;
  height: 500px;
  background: var(--warning);
}

/* Common Text Color Helpers */
.color-primary { color: var(--primary); }
.color-success { color: var(--success); }
.color-warning { color: var(--warning); }
.color-danger { color: var(--danger); }

/* Glassmorphism containers */
.glassmorphic {
  background: rgba(255, 255, 255, 0.7);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid rgba(14, 23, 38, 0.08);
  box-shadow: 0 10px 40px rgba(14, 23, 38, 0.04);
  border-radius: var(--r-lg);
  box-sizing: border-box;
}

/* Buttons */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  font-weight: 700;
  border: none;
  cursor: pointer;
  transition: all 0.2s ease;
  font-family: var(--font-family);
}
.btn-primary {
  background: var(--primary);
  color: #fff;
  border-radius: var(--r-pill);
  padding: 12px 28px;
  font-size: 15px;
  box-shadow: 0 4px 14px rgba(37, 99, 235, 0.25);
}
.btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(37, 99, 235, 0.35);
  background: #1d4ed8;
}
.btn-secondary {
  background: rgba(14, 23, 38, 0.05);
  color: var(--text-primary);
  border: 1px solid rgba(14, 23, 38, 0.05);
  border-radius: var(--r-pill);
  padding: 12px 28px;
  font-size: 15px;
}
.btn-secondary:hover {
  background: rgba(14, 23, 38, 0.08);
  transform: translateY(-2px);
}
.btn-lg {
  padding: 16px 36px;
  font-size: 17px;
}

/* -------------------
   Hero Section
------------------- */
.hero-section {
  text-align: center;
  padding: 80px 20px 70px;
  max-width: 820px;
  margin: 0 auto;
}
.badge-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: var(--primary-soft);
  color: var(--primary);
  padding: 6px 14px;
  border-radius: var(--r-pill);
  font-weight: 800;
  font-size: 12px;
  margin-bottom: 24px;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  animation: float 3s ease-in-out infinite;
}
.icon-sparkle {
  color: var(--primary);
}
.hero-title {
  font-size: 3.5rem;
  line-height: 1.15;
  font-weight: 800;
  margin-bottom: 24px;
  color: var(--text-primary);
  letter-spacing: -0.03em;
}
.gradient-text {
  background: var(--accent-gradient);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
.hero-subtitle {
  font-size: 1.15rem;
  line-height: 1.6;
  color: var(--text-secondary);
  margin-bottom: 36px;
  max-width: 680px;
  margin-left: auto;
  margin-right: auto;
}
.hero-ctas {
  display: flex;
  justify-content: center;
  gap: 16px;
}

/* -------------------
   Features Section
------------------- */
.features-section {
  padding: 60px 0;
  text-align: center;
}
.section-title {
  font-size: 2.25rem;
  font-weight: 800;
  color: var(--text-primary);
  margin-bottom: 8px;
  letter-spacing: -0.02em;
}
.section-subtitle {
  font-size: 1.05rem;
  color: var(--text-secondary);
  margin-bottom: 48px;
}
.features-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 24px;
}
.feature-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 32px 24px;
  text-align: left;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}
.feature-card:hover {
  transform: translateY(-6px);
  box-shadow: 0 12px 30px rgba(14, 23, 38, 0.06);
}
.icon-wrapper {
  width: 48px;
  height: 48px;
  border-radius: var(--r-md);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 20px;
}
.primary-soft { background: var(--primary-soft); }
.success-soft { background: var(--success-soft); }
.warning-soft { background: var(--warning-soft); }
.danger-soft { background: var(--danger-soft); }

.feature-card h3 {
  font-size: 1.25rem;
  font-weight: 700;
  margin-bottom: 12px;
}
.feature-card p {
  font-size: 0.95rem;
  line-height: 1.5;
  color: var(--text-secondary);
  margin: 0;
}

/* -------------------
   Interactive Demo Section
------------------- */
.demo-section {
  padding: 70px 0;
}
.demo-header {
  text-align: center;
}
.demo-container {
  max-width: 900px;
  margin: 0 auto;
}
.demo-tabs {
  display: flex;
  justify-content: center;
  gap: 12px;
  margin-bottom: 24px;
  background: rgba(14, 23, 38, 0.03);
  padding: 6px;
  border-radius: var(--r-pill);
  width: fit-content;
  margin-left: auto;
  margin-right: auto;
  border: 1px solid rgba(14, 23, 38, 0.03);
}
.tab-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  border: none;
  background: transparent;
  padding: 10px 20px;
  font-weight: 700;
  font-size: 14px;
  color: var(--text-secondary);
  border-radius: var(--r-pill);
  cursor: pointer;
  transition: all 0.2s ease;
  font-family: var(--font-family);
}
.tab-btn:hover {
  color: var(--text-primary);
}
.tab-btn.active {
  background: var(--surface);
  color: var(--primary);
  box-shadow: 0 4px 12px rgba(14, 23, 38, 0.05);
}

.demo-screen {
  padding: 30px;
  min-height: 380px;
}
.screen-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--border);
  padding-bottom: 20px;
  margin-bottom: 24px;
  flex-wrap: wrap;
  gap: 12px;
}
.screen-badge {
  font-size: 10px;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  background: var(--primary-soft);
  color: var(--primary);
  padding: 4px 8px;
  border-radius: var(--r-sm);
  display: inline-block;
  margin-bottom: 6px;
}
.bg-green-badge {
  background: var(--success-soft);
  color: var(--success);
}
.screen-title {
  font-size: 1.5rem;
  font-weight: 800;
  margin: 0;
}
.budget-pill {
  display: flex;
  flex-direction: column;
  gap: 4px;
  align-items: flex-end;
}
.budget-pill span {
  font-size: 12px;
  font-weight: 700;
  color: var(--text-secondary);
}
.mini-bar {
  width: 140px;
  height: 6px;
  background: var(--border);
  border-radius: var(--r-pill);
  overflow: hidden;
}
.mini-progress {
  height: 100%;
  background: var(--success);
  border-radius: var(--r-pill);
}

.coin-display {
  display: flex;
  align-items: center;
  gap: 6px;
  background: var(--warning-soft);
  border: 1px solid rgba(217, 119, 6, 0.15);
  padding: 6px 14px;
  border-radius: var(--r-pill);
}
.coin-icon {
  color: var(--warning);
  font-size: 16px;
}
.coin-display strong {
  font-size: 17px;
  font-weight: 800;
  color: var(--text-primary);
}
.cc-lbl {
  font-size: 13px;
  color: var(--text-secondary);
  font-weight: 700;
}

.screen-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 20px;
}
.widget-card {
  background: var(--surface);
  border: 1px solid rgba(14, 23, 38, 0.05);
  border-radius: var(--r-md);
  padding: 20px;
  box-shadow: 0 4px 12px rgba(14, 23, 38, 0.01);
}
.widget-card h4 {
  font-size: 15px;
  font-weight: 800;
  margin-top: 0;
  margin-bottom: 16px;
  color: var(--text-primary);
  border-bottom: 1px solid rgba(14, 23, 38, 0.03);
  padding-bottom: 8px;
}
.widget-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.list-item {
  display: flex;
  align-items: center;
  gap: 12px;
  background: var(--bg);
  border: 1px solid var(--border);
  padding: 10px 14px;
  border-radius: var(--r-sm);
  transition: all 0.2s ease;
}
.list-item:hover {
  border-color: rgba(14, 23, 38, 0.15);
}
.mock-avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 12px;
  color: #fff;
}
.bg-blue { background: var(--primary); }
.bg-green { background: var(--success); }
.bg-warning { background: var(--warning); }
.bg-danger { background: var(--danger); }

.item-info {
  flex: 1;
  display: flex;
  flex-direction: column;
}
.item-info .name {
  font-size: 13.5px;
  font-weight: 700;
  color: var(--text-primary);
}
.item-info .sub {
  font-size: 11px;
  color: var(--text-secondary);
}

.badge {
  font-size: 12px;
  font-weight: 800;
  padding: 4px 8px;
  border-radius: var(--r-sm);
}
.badge.coin {
  background: var(--primary-soft);
  color: var(--primary);
}
.badge.highlight {
  background: var(--success-soft);
  color: var(--success);
}

.mock-checkbox {
  width: 18px;
  height: 18px;
  border: 2px solid var(--border);
  border-radius: var(--r-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--surface);
}
.mock-checkbox.done {
  border-color: var(--success);
  background: var(--success-soft);
}
.list-item.action-needed {
  background: #fdfdfd;
}
.btn-action {
  border: none;
  font-weight: 800;
  font-size: 11px;
  padding: 6px 12px;
  border-radius: var(--r-pill);
  cursor: pointer;
  font-family: var(--font-family);
  transition: background 0.15s;
}
.approve-btn {
  background: var(--primary);
  color: #fff;
}
.approve-btn:hover { background: #1d4ed8; }
.redeem-btn {
  background: var(--success);
  color: #fff;
}
.redeem-btn:hover { background: #15803d; }

.mock-reward-icon {
  width: 28px;
  height: 28px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
}

/* -------------------
   Why CareCoins Section
------------------- */
.why-section {
  padding: 70px 0;
}
.why-grid {
  display: grid;
  grid-template-columns: 1.1fr 0.9fr;
  gap: 40px;
  align-items: center;
}
.why-text h2 {
  font-size: 2.25rem;
  font-weight: 800;
  margin-top: 10px;
  margin-bottom: 20px;
}
.why-text p {
  font-size: 1.05rem;
  line-height: 1.6;
  margin-bottom: 30px;
}
.why-perks {
  display: flex;
  flex-direction: column;
  gap: 20px;
}
.perk-row {
  display: flex;
  gap: 16px;
  align-items: flex-start;
}
.perk-icon {
  margin-top: 2px;
  flex-shrink: 0;
}
.perk-row strong {
  display: block;
  font-size: 15px;
  font-weight: 700;
  color: var(--text-primary);
  margin-bottom: 4px;
}
.perk-row p {
  font-size: 13.5px;
  line-height: 1.4;
  color: var(--text-secondary);
  margin: 0;
}

.why-visual {
  padding: 24px;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
.visual-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--border);
  padding-bottom: 12px;
  margin-bottom: 16px;
}
.visual-header h4 {
  margin: 0;
  font-size: 14px;
  font-weight: 800;
  color: var(--text-primary);
}
.ledger-lock {
  font-size: 9px;
  font-weight: 800;
  background: rgba(14, 23, 38, 0.05);
  color: var(--text-secondary);
  padding: 2px 6px;
  border-radius: var(--r-sm);
  letter-spacing: 0.03em;
}
.ledger-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.ledger-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 12px;
  padding: 8px 0;
  border-bottom: 1px dashed var(--border);
}
.ledger-row:last-child {
  border-bottom: none;
}
.l-date {
  color: var(--text-secondary);
  font-weight: 600;
  width: 70px;
}
.l-name {
  font-weight: 800;
  color: var(--text-primary);
  width: 90px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.l-desc {
  flex: 1;
  color: var(--text-secondary);
  padding-right: 8px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.l-amount {
  font-weight: 800;
  font-size: 13px;
  text-align: right;
  width: 60px;
}
.l-amount.positive { color: var(--success); }
.l-amount.negative { color: var(--danger); }

/* -------------------
   CTA Section
------------------- */
.cta-section {
  padding: 60px 0 80px;
  text-align: center;
}
.cta-container {
  padding: 60px 30px;
  max-width: 900px;
  margin: 0 auto;
}
.cta-container h2 {
  font-size: 2.25rem;
  font-weight: 800;
  margin-bottom: 16px;
  letter-spacing: -0.02em;
}
.cta-container p {
  font-size: 1.1rem;
  color: var(--text-secondary);
  max-width: 600px;
  margin: 0 auto 36px;
}

/* -------------------
   Footer Section
------------------- */
.landing-footer {
  border-top: 1px solid var(--border);
  padding: 40px 0 20px;
  margin-top: 40px;
}
.footer-container {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 20px;
}
.footer-logo {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.footer-logo strong {
  font-size: 17px;
  font-weight: 800;
  color: var(--text-primary);
}
.footer-logo span {
  font-size: 12px;
  color: var(--text-secondary);
}
.footer-links {
  display: flex;
  gap: 20px;
}
.footer-links a {
  text-decoration: none;
  font-weight: 700;
  font-size: 13.5px;
  color: var(--text-secondary);
  transition: color 0.15s;
}
.footer-links a:hover {
  color: var(--primary);
}

/* -------------------
   Animations
------------------- */
.fade-in {
  animation: simpleFadeIn 0.3s ease-out forwards;
}
@keyframes simpleFadeIn {
  from {
    opacity: 0;
    transform: translateY(6px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes float {
  0% { transform: translateY(0px); }
  50% { transform: translateY(-5px); }
  100% { transform: translateY(0px); }
}

/* -------------------
   Simulated Dashboard Layout
------------------- */
.sim-title-row {
  margin-bottom: 24px;
  text-align: left;
}
.sim-hub-title {
  color: var(--text-primary);
  font-size: 28px;
  font-weight: 800;
  letter-spacing: -0.8px;
  margin-bottom: 6px;
  margin-top: 0;
}
.sim-hub-subtitle {
  color: var(--text-secondary);
  font-size: 13px;
  margin: 0;
  line-height: 1.4;
}
.color-dark {
  color: var(--text-primary);
}

.sim-dashboard-grid {
  display: grid;
  grid-template-columns: 2fr 1.1fr;
  gap: 24px;
  text-align: left;
}

.sim-section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
}
.sim-section-title {
  font-size: 1.1rem;
  font-weight: 800;
  color: var(--text-primary);
}

.sim-members-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(105px, 1fr));
  gap: 12px;
  margin-bottom: 24px;
}

.sim-member-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 14px;
  display: flex;
  flex-direction: column;
  align-items: center;
  box-shadow: 0 1px 2px rgba(14,23,38,0.02);
  text-align: center;
  transition: transform 0.2s;
}
.sim-member-card:hover {
  transform: translateY(-2px);
}
.sim-member-card.color-0 { border-bottom: 4px solid var(--primary); }
.sim-member-card.color-1 { border-bottom: 4px solid var(--success); }
.sim-member-card.color-2 { border-bottom: 4px solid var(--warning); }
.sim-member-card.color-3 { border-bottom: 4px solid var(--danger); }

.sim-member-avatar {
  background: var(--bg);
  width: 44px;
  height: 44px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  box-shadow: inset 0 0 0 1px rgba(0,0,0,0.02);
}
.sim-member-name {
  font-weight: 800;
  font-size: 0.9rem;
  color: var(--text-primary);
  margin-top: 10px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  width: 100%;
}
.sim-member-coins {
  font-size: 11px;
  font-weight: 800;
  margin-top: 4px;
}

.sim-kpi-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
}

.sim-kpi-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 14px 16px;
  box-shadow: 0 1px 2px rgba(14, 23, 38, 0.02);
  display: flex;
  flex-direction: column;
}
.sim-kpi-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 6px;
}
.sim-kpi-label {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.08em;
  color: var(--text-secondary);
  text-transform: uppercase;
}
.sim-kpi-val-row {
  display: flex;
  align-items: baseline;
  gap: 4px;
}
.sim-kpi-value {
  font-size: 22px;
  font-weight: 800;
  line-height: 1;
}
.sim-kpi-unit {
  font-size: 12px;
  font-weight: 700;
  color: var(--text-secondary);
}
.sim-kpi-subtitle {
  font-size: 11px;
  color: var(--text-secondary);
  margin-top: 4px;
}
.sim-kpi-progress {
  height: 3px;
  background: var(--bg);
  border-radius: 999px;
  margin-top: 10px;
  overflow: hidden;
}
.sim-kpi-progress-fill {
  height: 100%;
  border-radius: 999px;
}
.bg-success {
  background: var(--success);
}

.sim-activity-container {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 18px;
  height: 100%;
  display: flex;
  flex-direction: column;
}
.sim-activity-title {
  font-size: 14px;
  font-weight: 800;
  color: var(--text-primary);
  margin-top: 0;
  margin-bottom: 16px;
}
.sim-activity-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.sim-activity-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
}
.sim-act-icon {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1rem;
  flex-shrink: 0;
  font-weight: bold;
}
.bg-blue-soft { background: var(--primary-soft); }
.text-blue { color: var(--primary); }
.bg-red-soft { background: var(--danger-soft); }
.text-red { color: var(--danger); }

.sim-act-details {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.sim-act-desc {
  font-weight: 800;
  color: var(--text-primary);
  font-size: 12px;
  line-height: 1.3;
}
.sim-act-desc strong {
  font-weight: 600;
  color: var(--text-secondary);
}
.sim-act-footer {
  display: flex;
  align-items: center;
  gap: 8px;
}
.sim-act-time {
  font-size: 10px;
  font-weight: 700;
  color: var(--text-secondary);
}
.sim-act-amount {
  font-size: 10px;
  font-weight: 800;
}
.font-bold {
  font-weight: 800;
}

@media (max-width: 860px) {
  .sim-dashboard-grid {
    grid-template-columns: 1fr;
    gap: 20px;
  }
}

@media (max-width: 900px) {
  .why-grid {
    grid-template-columns: 1fr;
    gap: 40px;
  }
  .why-visual {
    padding: 24px;
  }
}

@media (max-width: 768px) {
  .hero-title {
    font-size: 2.5rem;
  }
  .section-title {
    font-size: 1.75rem;
  }
  .why-text h2 {
    font-size: 1.75rem;
  }
  .cta-container h2 {
    font-size: 1.75rem;
  }
  .demo-screen {
    padding: 16px;
  }
  .screen-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 480px) {
  .hero-title {
    font-size: 2rem;
  }
  .hero-subtitle {
    font-size: 1rem;
  }
  .hero-ctas {
    flex-direction: column;
    gap: 12px;
    align-items: stretch;
    max-width: 280px;
    margin: 0 auto;
  }
  .tab-btn {
    padding: 8px 12px;
    font-size: 12px;
  }
}
</style>
