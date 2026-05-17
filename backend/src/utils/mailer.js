import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);
const FROM = process.env.EMAIL_FROM || 'CareCoins <noreply@mycarecoins.app>';
const APP_URL = process.env.APP_URL || 'https://mycarecoins.app';

export async function sendInvitationEmail({ toEmail, toName, inviterName, familyName }) {
  if (!process.env.RESEND_API_KEY) {
    console.log(`[MOCK EMAIL] Invitation to ${toEmail} for family "${familyName}" by ${inviterName}`);
    return;
  }

  const greeting = toName ? `Hi ${toName},` : 'Hi,';

  await resend.emails.send({
    from: FROM,
    to: toEmail,
    subject: `You've been invited to join ${familyName} on CareCoins`,
    html: `
<!DOCTYPE html>
<html>
<body style="font-family: sans-serif; background: #f8fafc; margin: 0; padding: 32px;">
  <div style="max-width: 480px; margin: 0 auto; background: #fff; border-radius: 12px; padding: 36px; box-shadow: 0 1px 4px rgba(0,0,0,0.08);">
    <h2 style="margin: 0 0 8px; color: #1e293b;">You're invited!</h2>
    <p style="color: #475569; margin: 0 0 24px;">${greeting}<br><br>
      <strong>${inviterName}</strong> has invited you to join the
      <strong>${familyName}</strong> family on <strong>CareCoins</strong>.
    </p>
    <a href="${APP_URL}" style="display: inline-block; background: #6366f1; color: #fff; text-decoration: none; border-radius: 8px; padding: 12px 28px; font-weight: 600; font-size: 0.95rem;">
      Open CareCoins
    </a>
    <p style="color: #94a3b8; font-size: 0.8rem; margin: 28px 0 0;">
      Sign in with this email address (${toEmail}) and you'll see the invitation waiting for you.
    </p>
  </div>
</body>
</html>`,
  });
}