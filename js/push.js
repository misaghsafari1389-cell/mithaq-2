import {supabase,SUPABASE_URL,SUPABASE_KEY,PUSH_PUBLIC_KEY} from './push-config.js';
function decodeKey(value){const pad='='.repeat((4-value.length%4)%4);const raw=atob((value+pad).replace(/-/g,'+').replace(/_/g,'/'));return Uint8Array.from(raw,c=>c.charCodeAt(0))}
export async function enablePhoneNotifications(){
  if(!('Notification' in window)||!('serviceWorker' in navigator)||!('PushManager' in window)) throw Error('این مرورگر اعلان پوش را پشتیبانی نمی‌کند. در اندروید Chrome یا در iPhone نسخه ۱۶.۴ به بعد، سایت را به صفحه اصلی اضافه کنید.');
  const permission=await Notification.requestPermission();
  if(permission!=='granted') throw Error(permission==='denied'?'اجازه اعلان رد شد؛ از تنظیمات مرورگر آن را برای این سایت فعال کنید.':'اجازه اعلان انتخاب نشد.');
  const adminSite=location.pathname.includes('/admin/');const registration=await navigator.serviceWorker.register(adminSite?'../sw.js':'./sw.js',{scope:adminSite?'../':'./'});
  await navigator.serviceWorker.ready;
  let subscription=await registration.pushManager.getSubscription();
  if(subscription){try{await subscription.unsubscribe()}catch{}}subscription=await registration.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:decodeKey(PUSH_PUBLIC_KEY)});
  const json=subscription.toJSON();
  const {error}=await supabase.rpc('mithaq_save_push_subscription',{p_endpoint:json.endpoint,p_p256dh:json.keys?.p256dh,p_auth:json.keys?.auth});
  if(error) throw error;
  return true;
}
export async function sendPushForReport(report){
  try{await fetch(`${SUPABASE_URL}/functions/v1/mithaq-notify-push`,{method:'POST',headers:{'Content-Type':'application/json','apikey':SUPABASE_KEY},body:JSON.stringify({report_id:report.report_id,upload_token:report.upload_token})})}catch{}
}
