<script setup>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { ArrowRight, ShieldCheck, ShoppingBag, TrendingUp } from 'lucide-vue-next';

const router = useRouter();
const activeTab = ref('caregiver');

const steps = [
  {
    title: 'Define tasks',
    body: 'Create templates for care and household work. Set a coin value and duration for each one.',
    color: 'primary',
  },
  {
    title: 'Schedule routines',
    body: 'Place tasks on a shared daily timeline. Set up recurring assignments across caregivers.',
    color: 'success',
  },
  {
    title: 'Complete and earn',
    body: 'Members check off tasks. Caregivers validate with a tap — coins land immediately in the earner\'s account.',
    color: 'warning',
  },
  {
    title: 'Spend on rewards',
    body: 'Your family\'s private store holds whatever you decide is worth earning toward. Coins spent, rewards given.',
    color: 'danger',
  },
];

onMounted(() => {
  const prefersMotion = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (!prefersMotion) return;

  const els = Array.from(document.querySelectorAll('[data-reveal]'));
  els.forEach(el => el.classList.add('reveal-init'));

  const io = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        e.target.classList.remove('reveal-init');
        io.unobserve(e.target);
      }
    });
  }, { threshold: 0.07 });

  els.forEach(el => io.observe(el));
});
</script>

<template>
  <div class="landing">

    <!-- ── HERO ──────────────────────────────────── -->
    <section class="hero">
      <div class="inner hero-inner">

        <!-- Text column -->
        <div class="hero-text">
          <div class="hero-kicker">For families</div>
          <h1 class="hero-h1">
            Every caregiver counted.<br>
            <span class="hero-accent">Every task rewarded.</span>
          </h1>
          <p class="hero-sub">
            CareCoins tracks who does what in your household, pays out coins from a shared monthly budget, and lets your family spend earnings in a private rewards store.
          </p>
          <div class="hero-ctas">
            <button class="btn-primary" @click="router.push('/login')">
              Get started free <ArrowRight :size="16" />
            </button>
            <button class="btn-ghost" @click="router.push('/login')">Sign in</button>
          </div>
        </div>

        <!-- Visual column: phone mockup + family SVG -->
        <div class="hero-visual">
          <div class="phone-frame">
            <div class="phone-notch"></div>
            <div class="phone-screen">
              <!-- Status bar -->
              <div class="ps-status">
                <span>9:41</span>
                <span>●●●</span>
              </div>
              <!-- App header -->
              <div class="ps-header">
                <span class="ps-date">Mon, Jun 2</span>
                <span class="ps-coin">🪙 460cc</span>
              </div>
              <!-- Progress bar -->
              <div class="ps-prog">
                <div class="ps-prog-track"><div class="ps-prog-fill"></div></div>
                <span class="ps-prog-label">2/5 done</span>
              </div>
              <!-- Timeline -->
              <div class="ps-tl">
                <div class="ps-row">
                  <span class="ps-time">8:00</span>
                  <div class="ps-card ps-blue">
                    <div class="ps-card-title">School run (Leo)</div>
                    <div class="ps-card-meta">30m · 🪙 15cc ✓</div>
                  </div>
                </div>
                <div class="ps-now"><span>NOW</span></div>
                <div class="ps-row">
                  <span class="ps-time">14:00</span>
                  <div class="ps-card ps-green">
                    <div class="ps-card-title">Walk the dog</div>
                    <div class="ps-card-meta">30m · 🪙 10cc</div>
                  </div>
                </div>
                <div class="ps-gap">1h free</div>
                <div class="ps-row">
                  <span class="ps-time">18:00</span>
                  <div class="ps-card ps-amber">
                    <div class="ps-card-title">Dinner prep</div>
                    <div class="ps-card-meta">45m · 🪙 20cc</div>
                  </div>
                </div>
              </div>
              <!-- Bottom nav -->
              <div class="ps-nav">
                <div class="ps-nav-i ps-nav-on">📅<span>Today</span></div>
                <div class="ps-nav-i">🏠<span>Hub</span></div>
                <div class="ps-nav-i">🏆<span>Rewards</span></div>
                <div class="ps-nav-i">📊<span>Stats</span></div>
                <div class="ps-nav-i">👤<span>Me</span></div>
              </div>
            </div>
          </div>

          <!-- Family SVG illustration -->
          <svg class="family-svg" viewBox="0 0 200 72" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
            <!-- Adult 1 -->
            <circle cx="34" cy="16" r="12" fill="#2563EB"/>
            <rect x="22" y="31" width="24" height="30" rx="7" fill="#2563EB"/>
            <!-- Adult 2 -->
            <circle cx="74" cy="19" r="11" fill="#16A34A"/>
            <rect x="63" y="33" width="22" height="27" rx="7" fill="#16A34A"/>
            <!-- Child 1 -->
            <circle cx="110" cy="26" r="9" fill="#D97706"/>
            <rect x="101" y="38" width="18" height="22" rx="6" fill="#D97706"/>
            <!-- Child 2 -->
            <circle cx="143" cy="31" r="7" fill="#DC2626"/>
            <rect x="136" y="41" width="14" height="17" rx="5" fill="#DC2626"/>
            <!-- Ground line -->
            <line x1="12" y1="62" x2="170" y2="62" stroke="rgba(255,255,255,0.18)" stroke-width="1.5" stroke-linecap="round"/>
          </svg>
        </div>

      </div>
    </section>

    <!-- ── HOW IT WORKS ──────────────────────────── -->
    <section class="section section--white">
      <div class="inner">
        <div class="section-head" data-reveal>
          <h2>How it works</h2>
          <p>Four steps, one shared ledger.</p>
        </div>
        <div class="steps">
          <div
            v-for="(step, i) in steps"
            :key="i"
            class="step"
            data-reveal
            :style="`transition-delay: ${i * 90}ms`"
          >
            <div :class="['step-n', `step-n--${step.color}`]">{{ i + 1 }}</div>
            <h3 class="step-title">{{ step.title }}</h3>
            <p class="step-body">{{ step.body }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ── DEMO ──────────────────────────────────── -->
    <section class="section section--tint">
      <div class="inner">
        <div class="section-head" data-reveal>
          <h2>See it in action</h2>
          <p>A preview of what your family sees every day.</p>
        </div>
        <div class="demo-wrap" data-reveal>
          <div class="demo-tabs">
            <button :class="['demo-tab', activeTab === 'caregiver' && 'demo-tab--on']" @click="activeTab = 'caregiver'">
              <ShieldCheck :size="15" />Family Dashboard
            </button>
            <button :class="['demo-tab', activeTab === 'marketplace' && 'demo-tab--on']" @click="activeTab = 'marketplace'">
              <ShoppingBag :size="15" />Activities &amp; Rewards
            </button>
          </div>

          <div class="demo-screen">
            <!-- Family Dashboard -->
            <div v-if="activeTab === 'caregiver'" class="screen-content fade-in">
              <div class="sim-title-row">
                <h3 class="sim-hub-title">Family Hub</h3>
                <p class="sim-hub-subtitle">
                  Good morning, Mama! Your family has earned <strong class="color-dark">460 cc</strong> today. <strong class="color-dark">2 tasks</strong> are waiting for validation.
                </p>
              </div>
              <div class="sim-dashboard-grid">
                <div class="sim-left-col">
                  <div class="sim-section-header">
                    <span class="sim-section-title">Active Family Members</span>
                  </div>
                  <div class="sim-members-grid">
                    <div class="sim-member-card color-0">
                      <div class="sim-member-avatar">👩🏽</div>
                      <div class="sim-member-name">Mama</div>
                      <div class="sim-member-coins text-color-0">● 120 cc</div>
                    </div>
                    <div class="sim-member-card color-1">
                      <div class="sim-member-avatar">👨🏽</div>
                      <div class="sim-member-name">Papa</div>
                      <div class="sim-member-coins text-color-1">● 340 cc</div>
                    </div>
                    <div class="sim-member-card color-2">
                      <div class="sim-member-avatar">👶🏽</div>
                      <div class="sim-member-name">Leo</div>
                      <div class="sim-member-coins text-color-2">● 80 cc</div>
                    </div>
                    <div class="sim-member-card color-3">
                      <div class="sim-member-avatar">👧🏽</div>
                      <div class="sim-member-name">Sofia</div>
                      <div class="sim-member-coins text-color-3">● 160 cc</div>
                    </div>
                  </div>
                  <div class="sim-kpi-grid">
                    <div class="sim-kpi-card">
                      <div class="sim-kpi-top"><span class="sim-kpi-label">Family Balance</span></div>
                      <div class="sim-kpi-val-row">
                        <span class="sim-kpi-value color-primary">460</span>
                        <span class="sim-kpi-unit">cc</span>
                      </div>
                      <div class="sim-kpi-subtitle">across 4 members</div>
                    </div>
                    <div class="sim-kpi-card">
                      <div class="sim-kpi-top"><span class="sim-kpi-label">Tasks Today</span></div>
                      <div class="sim-kpi-val-row">
                        <span class="sim-kpi-value color-success">2/5</span>
                      </div>
                      <div class="sim-kpi-subtitle">2 awaiting validation</div>
                      <div class="sim-kpi-progress">
                        <div class="sim-kpi-progress-fill bg-success" style="width: 40%;"></div>
                      </div>
                    </div>
                    <div class="sim-kpi-card">
                      <div class="sim-kpi-top"><span class="sim-kpi-label">Open Bounties</span></div>
                      <div class="sim-kpi-val-row">
                        <span class="sim-kpi-value color-warning">1</span>
                      </div>
                      <div class="sim-kpi-subtitle">15 cc up for grabs</div>
                    </div>
                    <div class="sim-kpi-card">
                      <div class="sim-kpi-top"><span class="sim-kpi-label">Recent Activity</span></div>
                      <div class="sim-kpi-val-row">
                        <span class="sim-kpi-value color-dark">3</span>
                      </div>
                      <div class="sim-kpi-subtitle">completed recently</div>
                    </div>
                  </div>
                </div>
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

            <!-- Activities & Rewards -->
            <div v-if="activeTab === 'marketplace'" class="screen-content fade-in">
              <div class="screen-header">
                <h3 class="screen-title">Activities &amp; Rewards Store</h3>
                <div class="coin-display">
                  <span class="coin-icon">🪙</span>
                  <strong>460</strong>
                  <span class="cc-lbl">Family Pool</span>
                </div>
              </div>
              <div class="screen-grid">
                <div class="widget-card">
                  <h4>Task Templates</h4>
                  <div class="widget-list">
                    <div class="list-item">
                      <div class="mock-reward-icon bg-blue">📚</div>
                      <div class="item-info">
                        <span class="name">Do Homework</span>
                        <span class="sub">Care · 60 min</span>
                      </div>
                      <span class="badge highlight">+15 cc</span>
                    </div>
                    <div class="list-item">
                      <div class="mock-reward-icon bg-green">🌱</div>
                      <div class="item-info">
                        <span class="name">Walk the Dog</span>
                        <span class="sub">Household · 30 min</span>
                      </div>
                      <span class="badge highlight">+10 cc</span>
                    </div>
                  </div>
                </div>
                <div class="widget-card">
                  <h4>Rewards Store</h4>
                  <div class="widget-list">
                    <div class="list-item">
                      <div class="mock-reward-icon bg-warning">🎮</div>
                      <div class="item-info">
                        <span class="name">1 Hour Video Games</span>
                        <span class="sub">Cost: 50 cc · 3 left</span>
                      </div>
                      <button class="btn-action redeem-btn">Redeem</button>
                    </div>
                    <div class="list-item">
                      <div class="mock-reward-icon bg-danger">🍦</div>
                      <div class="item-info">
                        <span class="name">Ice Cream Treat</span>
                        <span class="sub">Cost: 30 cc</span>
                      </div>
                      <button class="btn-action redeem-btn">Redeem</button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ── WHY ───────────────────────────────────── -->
    <section class="section section--white">
      <div class="inner">
        <div class="why-grid">
          <div class="why-text" data-reveal>
            <h2>Fairness, not guesswork</h2>
            <p>
              Chore charts get ignored because they carry no weight. CareCoins puts a real value on caregiving work — tracked, validated, and paid out from a budget the whole family can see.
            </p>
            <div class="perks">
              <div class="perk">
                <TrendingUp :size="20" class="perk-icon" />
                <div>
                  <strong>Contribution history at a glance</strong>
                  <p>See who did what this month, this year, and since you started. Charts by category, person, and trend.</p>
                </div>
              </div>
              <div class="perk">
                <ShieldCheck :size="20" class="perk-icon" />
                <div>
                  <strong>One family, one ledger</strong>
                  <p>Every coin earned and spent is recorded. Caregivers approve tasks; the ledger does not lie.</p>
                </div>
              </div>
            </div>
          </div>
          <div class="ledger-card" data-reveal>
            <div class="ledger-card-head">
              <h4>Recent transactions</h4>
              <span class="ledger-badge">Verified</span>
            </div>
            <div class="ledger-rows">
              <div class="ledger-row">
                <span class="l-date">Today</span>
                <span class="l-name">Mama</span>
                <span class="l-desc">Redeemed: Coffee Treat</span>
                <span class="l-amt negative">-30 cc</span>
              </div>
              <div class="ledger-row">
                <span class="l-date">Today</span>
                <span class="l-name">Papa</span>
                <span class="l-desc">Completed: Feed Pet (Fido)</span>
                <span class="l-amt positive">+10 cc</span>
              </div>
              <div class="ledger-row">
                <span class="l-date">Yesterday</span>
                <span class="l-name">Mama</span>
                <span class="l-desc">Completed: Clean Room (Sofia)</span>
                <span class="l-amt positive">+20 cc</span>
              </div>
              <div class="ledger-row">
                <span class="l-date">Yesterday</span>
                <span class="l-name">System</span>
                <span class="l-desc">Budget allocation</span>
                <span class="l-amt positive">+500 cc</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ── CTA ───────────────────────────────────── -->
    <section class="cta-section" data-reveal>
      <div class="inner cta-inner">
        <h2>Your family's shared economy, starting today.</h2>
        <p>Five minutes to set up. No subscriptions, no algorithms.</p>
        <button class="btn-cta" @click="router.push('/login')">
          Create your family <ArrowRight :size="18" />
        </button>
      </div>
    </section>

    <!-- ── FOOTER ────────────────────────────────── -->
    <footer class="footer">
      <div class="inner footer-inner">
        <div class="footer-brand">
          <strong>CareCoins</strong>
          <span>© 2026. All rights reserved.</span>
        </div>
        <div class="footer-links">
          <a href="#" @click.prevent="router.push('/login')">Log in</a>
          <a href="#" @click.prevent="router.push('/login')">Register</a>
        </div>
      </div>
    </footer>

  </div>
</template>

<style scoped>
/* ── Root ────────────────────────────────────── */
.landing {
  width: 100%;
  font-family: var(--font-family);
}
.inner {
  max-width: 1080px;
  margin: 0 auto;
  padding: 0 24px;
}

/* ── Sections ────────────────────────────────── */
.section        { padding: 88px 0; }
.section--white { background: var(--surface); }
.section--tint  { background: var(--bg); }

.section-head {
  text-align: center;
  margin-bottom: 56px;
}
.section-head h2 {
  font-size: clamp(1.75rem, 3vw + 0.25rem, 2.5rem);
  font-weight: 800;
  color: var(--text-primary);
  letter-spacing: -0.02em;
  margin-bottom: 10px;
  text-wrap: balance;
}
.section-head p {
  font-size: 1.05rem;
  color: var(--text-secondary);
}

/* ── Hero ────────────────────────────────────── */
.hero {
  background: #0E1726;
  padding: 88px 0 100px;
}
.hero-inner {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 64px;
  align-items: center;
}
.hero-text { max-width: 560px; }

.hero-kicker {
  display: inline-block;
  border: 1px solid rgba(255,255,255,0.14);
  color: rgba(255,255,255,0.65);
  font-size: 0.78rem;
  font-weight: 700;
  padding: 5px 14px;
  border-radius: 9999px;
  margin-bottom: 28px;
  letter-spacing: 0.02em;
}
.hero-h1 {
  font-size: clamp(2rem, 4vw + 0.5rem, 4rem);
  font-weight: 800;
  line-height: 1.08;
  letter-spacing: -0.03em;
  color: #fff;
  margin-bottom: 24px;
  text-wrap: balance;
}
.hero-accent { color: #93C5FD; }

.hero-sub {
  font-size: clamp(0.95rem, 1.2vw + 0.3rem, 1.1rem);
  line-height: 1.65;
  color: rgba(255,255,255,0.75);
  margin: 0 0 40px;
}
.hero-ctas {
  display: flex;
  gap: 14px;
  flex-wrap: wrap;
}

/* ── Phone mockup ────────────────────────────── */
.hero-visual {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 20px;
  flex-shrink: 0;
}
.phone-frame {
  width: 210px;
  background: #111827;
  border-radius: 36px;
  padding: 10px;
  box-shadow:
    0 0 0 1px rgba(255,255,255,0.06),
    0 40px 80px rgba(0,0,0,0.55),
    0 16px 32px rgba(0,0,0,0.3);
}
.phone-notch {
  width: 72px;
  height: 22px;
  background: #111827;
  border-radius: 0 0 16px 16px;
  margin: 0 auto 4px;
  position: relative;
}
.phone-notch::after {
  content: '';
  position: absolute;
  top: 6px;
  left: 50%;
  transform: translateX(-50%);
  width: 48px;
  height: 5px;
  background: #1e2d40;
  border-radius: 9999px;
}
.phone-screen {
  background: var(--bg);
  border-radius: 26px;
  overflow: hidden;
  height: 390px;
  display: flex;
  flex-direction: column;
}

/* Phone screen content */
.ps-status {
  display: flex;
  justify-content: space-between;
  padding: 8px 14px 3px;
  font-size: 8.5px;
  font-weight: 700;
  color: var(--text-secondary);
}
.ps-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 2px 14px 8px;
  border-bottom: 1px solid var(--border);
}
.ps-date { font-size: 11px; font-weight: 800; color: var(--text-primary); }
.ps-coin {
  font-size: 9px; font-weight: 800;
  background: var(--warning-soft);
  color: var(--warning);
  padding: 3px 8px;
  border-radius: 9999px;
}
.ps-prog {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 7px 14px 5px;
}
.ps-prog-track {
  flex: 1; height: 4px;
  background: var(--border);
  border-radius: 9999px; overflow: hidden;
}
.ps-prog-fill {
  width: 40%; height: 100%;
  background: var(--success);
  border-radius: 9999px;
}
.ps-prog-label { font-size: 7.5px; font-weight: 700; color: var(--text-secondary); white-space: nowrap; }

.ps-tl {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  gap: 5px;
  padding: 4px 0 2px;
}
.ps-row { display: flex; align-items: flex-start; gap: 6px; padding: 0 10px 0 12px; }
.ps-time { font-size: 7.5px; color: var(--text-secondary); font-weight: 700; min-width: 28px; padding-top: 5px; text-align: right; }
.ps-card { flex: 1; border-radius: 8px; padding: 5px 9px; color: white; }
.ps-card-title { font-size: 9.5px; font-weight: 800; }
.ps-card-meta  { font-size: 8px; opacity: 0.82; margin-top: 1px; }
.ps-blue  { background: var(--primary); }
.ps-green { background: var(--success); }
.ps-amber { background: var(--warning); }

.ps-now {
  display: flex; align-items: center;
  padding: 1px 10px 1px 12px; gap: 5px;
}
.ps-now::before, .ps-now::after {
  content: ''; flex: 1; height: 1px; background: var(--danger);
}
.ps-now span { font-size: 6.5px; font-weight: 800; color: var(--danger); flex-shrink: 0; }

.ps-gap {
  text-align: center; font-size: 7.5px;
  color: var(--text-secondary); font-weight: 600;
  padding: 1px 0;
}

.ps-nav {
  display: flex; justify-content: space-around;
  padding: 6px 6px 10px;
  border-top: 1px solid var(--border);
  background: rgba(255,255,255,0.92);
  backdrop-filter: blur(8px);
  margin-top: auto;
}
.ps-nav-i {
  display: flex; flex-direction: column; align-items: center; gap: 1px;
  font-size: 13px; opacity: 0.35;
}
.ps-nav-i span { font-size: 6.5px; font-weight: 700; color: var(--text-secondary); opacity: 1; }
.ps-nav-on { opacity: 1; }
.ps-nav-on span { color: var(--primary); }

/* ── Family SVG ──────────────────────────────── */
.family-svg {
  width: 150px;
  opacity: 0.9;
}
.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: var(--primary);
  color: #fff;
  border: none;
  border-radius: 9999px;
  padding: 13px 28px;
  font-size: 15px;
  font-weight: 700;
  font-family: var(--font-family);
  cursor: pointer;
  box-shadow: 0 4px 18px rgba(37,99,235,0.4);
  transition: opacity 0.15s, transform 0.15s;
}
.btn-primary:hover  { opacity: 0.9; transform: translateY(-1px); }
.btn-primary:active { transform: scale(0.98); }
.btn-ghost {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: rgba(255,255,255,0.07);
  color: rgba(255,255,255,0.78);
  border: 1px solid rgba(255,255,255,0.14);
  border-radius: 9999px;
  padding: 13px 28px;
  font-size: 15px;
  font-weight: 700;
  font-family: var(--font-family);
  cursor: pointer;
  transition: background 0.15s;
}
.btn-ghost:hover { background: rgba(255,255,255,0.12); }

/* ── Steps ───────────────────────────────────── */
.steps {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 2rem;
  position: relative;
}
.steps::before {
  content: '';
  position: absolute;
  top: 19px;
  left: 56px;
  right: 56px;
  height: 1px;
  background: var(--border);
  pointer-events: none;
}
.step { position: relative; }
.step-n {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 1rem;
  margin-bottom: 18px;
  position: relative;
  z-index: 1;
}
.step-n--primary { background: var(--primary-soft); color: var(--primary); }
.step-n--success { background: var(--success-soft); color: var(--success); }
.step-n--warning { background: var(--warning-soft); color: var(--warning); }
.step-n--danger  { background: var(--danger-soft);  color: var(--danger);  }

.step-title {
  font-size: 1.05rem;
  font-weight: 800;
  color: var(--text-primary);
  margin-bottom: 10px;
  letter-spacing: -0.01em;
}
.step-body {
  font-size: 0.9rem;
  line-height: 1.6;
  color: var(--text-secondary);
  margin: 0;
}

/* ── Demo ────────────────────────────────────── */
.demo-wrap { max-width: 920px; margin: 0 auto; }

.demo-tabs {
  display: flex;
  justify-content: center;
  gap: 6px;
  margin-bottom: 20px;
  background: var(--surface);
  border: 1px solid var(--border);
  padding: 5px;
  border-radius: 9999px;
  width: fit-content;
  margin-left: auto;
  margin-right: auto;
}
.demo-tab {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  border: none;
  background: transparent;
  padding: 9px 18px;
  font-weight: 700;
  font-size: 13px;
  color: var(--text-secondary);
  border-radius: 9999px;
  cursor: pointer;
  transition: all 0.15s;
  font-family: var(--font-family);
}
.demo-tab:hover  { color: var(--text-primary); }
.demo-tab--on    { background: var(--primary); color: #fff; }
.demo-screen {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 28px;
  min-height: 380px;
  box-shadow: 0 4px 24px rgba(14,23,38,0.05);
}

/* ── Why ─────────────────────────────────────── */
.why-grid {
  display: grid;
  grid-template-columns: 1.15fr 0.85fr;
  gap: 56px;
  align-items: center;
}
.why-text h2 {
  font-size: clamp(1.75rem, 3vw, 2.25rem);
  font-weight: 800;
  color: var(--text-primary);
  letter-spacing: -0.02em;
  margin-bottom: 18px;
  text-wrap: balance;
}
.why-text > p {
  font-size: 1.05rem;
  line-height: 1.65;
  color: var(--text-secondary);
  margin-bottom: 32px;
  max-width: 52ch;
}
.perks { display: flex; flex-direction: column; gap: 24px; }
.perk  { display: flex; gap: 14px; align-items: flex-start; }
.perk-icon { color: var(--primary); margin-top: 2px; flex-shrink: 0; }
.perk strong {
  display: block;
  font-size: 0.95rem;
  font-weight: 800;
  color: var(--text-primary);
  margin-bottom: 4px;
}
.perk p {
  font-size: 0.88rem;
  line-height: 1.5;
  color: var(--text-secondary);
  margin: 0;
}

.ledger-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 22px;
  box-shadow: 0 2px 12px rgba(14,23,38,0.04);
}
.ledger-card-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-bottom: 12px;
  margin-bottom: 4px;
  border-bottom: 1px solid var(--border);
}
.ledger-card-head h4 {
  margin: 0;
  font-size: 14px;
  font-weight: 800;
  color: var(--text-primary);
}
.ledger-badge {
  font-size: 10px;
  font-weight: 700;
  padding: 3px 8px;
  border-radius: 9999px;
  background: var(--success-soft);
  color: var(--success);
}
.ledger-rows { display: flex; flex-direction: column; }
.ledger-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  padding: 9px 0;
  border-bottom: 1px solid var(--border);
}
.ledger-row:last-child { border-bottom: none; }
.l-date { color: var(--text-secondary); font-weight: 600; min-width: 62px; }
.l-name { font-weight: 800; color: var(--text-primary); min-width: 46px; }
.l-desc { flex: 1; color: var(--text-secondary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.l-amt  { font-weight: 800; min-width: 50px; text-align: right; }
.l-amt.positive { color: var(--success); }
.l-amt.negative { color: var(--danger); }

/* ── CTA ─────────────────────────────────────── */
.cta-section {
  background: var(--primary);
  padding: 96px 0;
}
.cta-inner { text-align: center; }
.cta-section h2 {
  font-size: clamp(1.75rem, 3.5vw + 0.25rem, 2.75rem);
  font-weight: 800;
  color: #fff;
  letter-spacing: -0.02em;
  margin-bottom: 14px;
  text-wrap: balance;
}
.cta-section p {
  font-size: 1.1rem;
  color: rgba(255,255,255,0.82);
  margin-bottom: 36px;
}
.btn-cta {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  background: #fff;
  color: var(--primary);
  border: none;
  border-radius: 9999px;
  padding: 15px 36px;
  font-size: 16px;
  font-weight: 800;
  font-family: var(--font-family);
  cursor: pointer;
  box-shadow: 0 4px 20px rgba(0,0,0,0.15);
  transition: opacity 0.15s, transform 0.15s;
}
.btn-cta:hover  { opacity: 0.96; transform: translateY(-1px); }
.btn-cta:active { transform: scale(0.98); }

/* ── Footer ──────────────────────────────────── */
.footer {
  background: var(--surface);
  border-top: 1px solid var(--border);
  padding: 32px 0;
}
.footer-inner {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
}
.footer-brand { display: flex; flex-direction: column; gap: 3px; }
.footer-brand strong { font-size: 16px; font-weight: 800; color: var(--text-primary); }
.footer-brand span   { font-size: 12px; color: var(--text-secondary); }
.footer-links { display: flex; gap: 20px; }
.footer-links a {
  text-decoration: none;
  font-weight: 700;
  font-size: 13.5px;
  color: var(--text-secondary);
  transition: color 0.15s;
}
.footer-links a:hover { color: var(--primary); }

/* ── Scroll reveal ───────────────────────────── */
[data-reveal] {
  transition: opacity 0.55s ease-out, transform 0.55s ease-out;
}
.reveal-init {
  opacity: 0;
  transform: translateY(22px);
}

/* ── Fade (demo tab switch) ──────────────────── */
.fade-in { animation: fadeIn 0.22s ease-out; }
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(4px); }
  to   { opacity: 1; transform: translateY(0); }
}

/* ── Sim: color helpers ──────────────────────── */
.color-primary { color: var(--primary); }
.color-success { color: var(--success); }
.color-warning { color: var(--warning); }
.color-danger  { color: var(--danger); }
.color-dark    { color: var(--text-primary); }

/* ── Sim: dashboard layout ───────────────────── */
.sim-title-row    { margin-bottom: 20px; }
.sim-hub-title    { font-size: 22px; font-weight: 800; color: var(--text-primary); letter-spacing: -0.5px; margin: 0 0 4px; }
.sim-hub-subtitle { color: var(--text-secondary); font-size: 12px; margin: 0; line-height: 1.4; }

.sim-dashboard-grid {
  display: grid;
  grid-template-columns: 2fr 1.1fr;
  gap: 20px;
  text-align: left;
}
.sim-section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}
.sim-section-title { font-size: 1rem; font-weight: 800; color: var(--text-primary); }

.sim-members-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(100px, 1fr));
  gap: 10px;
  margin-bottom: 20px;
}
.sim-member-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}
.sim-member-card.color-0 { border-bottom: 3px solid var(--primary); }
.sim-member-card.color-1 { border-bottom: 3px solid var(--success); }
.sim-member-card.color-2 { border-bottom: 3px solid var(--warning); }
.sim-member-card.color-3 { border-bottom: 3px solid var(--danger); }
.sim-member-avatar {
  background: var(--bg);
  width: 40px; height: 40px;
  border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.3rem;
}
.sim-member-name { font-weight: 800; font-size: 0.8rem; color: var(--text-primary); margin-top: 8px; }
.sim-member-coins { font-size: 10px; font-weight: 800; margin-top: 3px; }
.text-color-0 { color: var(--primary); }
.text-color-1 { color: var(--success); }
.text-color-2 { color: var(--warning); }
.text-color-3 { color: var(--danger); }

.sim-kpi-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; }
.sim-kpi-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 12px 14px;
  display: flex; flex-direction: column;
}
.sim-kpi-top { margin-bottom: 5px; }
.sim-kpi-label {
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.06em;
  color: var(--text-secondary);
  text-transform: uppercase;
}
.sim-kpi-val-row { display: flex; align-items: baseline; gap: 4px; }
.sim-kpi-value   { font-size: 20px; font-weight: 800; line-height: 1; }
.sim-kpi-unit    { font-size: 11px; font-weight: 700; color: var(--text-secondary); }
.sim-kpi-subtitle { font-size: 10px; color: var(--text-secondary); margin-top: 3px; }
.sim-kpi-progress {
  height: 3px; background: var(--bg);
  border-radius: 999px; margin-top: 8px; overflow: hidden;
}
.sim-kpi-progress-fill { height: 100%; border-radius: 999px; }
.bg-success { background: var(--success); }

.sim-activity-container {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 16px;
  height: 100%;
}
.sim-activity-title { font-size: 13px; font-weight: 800; color: var(--text-primary); margin: 0 0 14px; }
.sim-activity-list  { display: flex; flex-direction: column; gap: 14px; }
.sim-activity-item  { display: flex; align-items: flex-start; gap: 10px; }
.sim-act-icon {
  width: 28px; height: 28px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.85rem; flex-shrink: 0; font-weight: bold;
}
.bg-blue-soft { background: var(--primary-soft); }
.text-blue    { color: var(--primary); }
.bg-red-soft  { background: var(--danger-soft); }
.text-red     { color: var(--danger); }
.sim-act-details { display: flex; flex-direction: column; gap: 2px; }
.sim-act-desc    { font-weight: 700; color: var(--text-primary); font-size: 11.5px; line-height: 1.3; }
.sim-act-desc strong { font-weight: 600; color: var(--text-secondary); }
.sim-act-footer  { display: flex; align-items: center; gap: 7px; }
.sim-act-time    { font-size: 9.5px; font-weight: 700; color: var(--text-secondary); }
.sim-act-amount  { font-size: 9.5px; font-weight: 800; }

/* ── Sim: marketplace screen ─────────────────── */
.screen-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--border);
  padding-bottom: 16px;
  margin-bottom: 20px;
  flex-wrap: wrap;
  gap: 10px;
}
.screen-title { font-size: 1.3rem; font-weight: 800; margin: 0; color: var(--text-primary); }
.coin-display {
  display: flex;
  align-items: center;
  gap: 5px;
  background: var(--warning-soft);
  border: 1px solid rgba(217,119,6,0.15);
  padding: 5px 12px;
  border-radius: 9999px;
}
.coin-icon { font-size: 14px; }
.coin-display strong { font-size: 15px; font-weight: 800; color: var(--text-primary); }
.cc-lbl { font-size: 12px; color: var(--text-secondary); font-weight: 700; }

.screen-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 18px;
}
.widget-card {
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: var(--r-md);
  padding: 18px;
}
.widget-card h4 { font-size: 13px; font-weight: 800; margin: 0 0 14px; color: var(--text-primary); padding-bottom: 8px; border-bottom: 1px solid var(--border); }
.widget-list { display: flex; flex-direction: column; gap: 10px; }
.list-item {
  display: flex; align-items: center; gap: 10px;
  background: var(--surface);
  border: 1px solid var(--border);
  padding: 9px 12px;
  border-radius: var(--r-sm);
}
.mock-reward-icon {
  width: 26px; height: 26px;
  border-radius: 6px;
  display: flex; align-items: center; justify-content: center;
  font-size: 13px; flex-shrink: 0;
}
.bg-blue    { background: var(--primary-soft); }
.bg-green   { background: var(--success-soft); }
.bg-warning { background: var(--warning-soft); }
.bg-danger  { background: var(--danger-soft); }
.item-info  { flex: 1; display: flex; flex-direction: column; }
.item-info .name { font-size: 12.5px; font-weight: 700; color: var(--text-primary); }
.item-info .sub  { font-size: 10.5px; color: var(--text-secondary); }
.badge { font-size: 11px; font-weight: 800; padding: 3px 7px; border-radius: var(--r-sm); }
.badge.highlight { background: var(--success-soft); color: var(--success); }
.btn-action {
  border: none;
  border-radius: 9999px;
  padding: 5px 11px;
  font-weight: 700;
  font-size: 11px;
  cursor: pointer;
  font-family: var(--font-family);
  transition: opacity 0.15s;
}
.btn-action:active { opacity: 0.8; }
.redeem-btn { background: var(--success); color: #fff; }

/* ── Responsive ──────────────────────────────── */

/* Large tablet — narrow the phone slightly */
@media (max-width: 1024px) {
  .hero-inner { gap: 40px; }
  .phone-frame { width: 190px; }
  .phone-screen { height: 352px; }
}

/* Tablet portrait — 1-column hero, phone above text, layouts stack */
@media (max-width: 900px) {
  .hero { padding: 64px 0 72px; }
  .hero-inner { grid-template-columns: 1fr; justify-items: center; text-align: center; }
  .hero-text { max-width: 580px; }
  .hero-sub { margin: 0 auto 36px; }
  .hero-ctas { justify-content: center; }
  .hero-visual { order: -1; }
  .phone-frame { width: 175px; }
  .phone-screen { height: 324px; }
  .why-grid { grid-template-columns: 1fr; gap: 32px; }
  .sim-dashboard-grid { grid-template-columns: 1fr; }
}

/* Phone landscape / phablet — hide visual, reduce vertical padding */
@media (max-width: 768px) {
  .hero { padding: 52px 0 60px; }
  .hero-inner { text-align: center; }
  .hero-visual { display: none; }
  .section { padding: 52px 0; }
  .cta-section { padding: 56px 0; }
  .section-head { margin-bottom: 40px; }
  .steps { grid-template-columns: repeat(2, 1fr); gap: 1.5rem; }
  .steps::before { display: none; }
  .demo-screen { padding: 16px; }
  .screen-grid { grid-template-columns: 1fr; }
}

/* Phone portrait — single column, compact spacing */
@media (max-width: 480px) {
  .hero { padding: 44px 0 52px; }
  .section { padding: 44px 0; }
  .cta-section { padding: 44px 0; }
  .section-head { margin-bottom: 32px; }
  .steps { grid-template-columns: 1fr; }
  .hero-ctas { flex-direction: column; align-items: stretch; max-width: 300px; margin: 0 auto; }
  .btn-primary, .btn-ghost { justify-content: center; }
  .demo-tabs { flex-direction: column; align-items: stretch; width: 100%; border-radius: var(--r-md); }
  .demo-tab { justify-content: center; }
  .sim-members-grid { grid-template-columns: repeat(2, 1fr); }
  .ledger-row { gap: 5px; }
  .l-date { min-width: 50px; }
  .l-name { min-width: 36px; }
  .footer-inner { flex-direction: column; align-items: flex-start; gap: 12px; }
}

/* ── Reduced motion ──────────────────────────── */
@media (prefers-reduced-motion: reduce) {
  [data-reveal] { transition: none; }
  .reveal-init  { opacity: 1; transform: none; }
  .fade-in      { animation: none; }
}
</style>
