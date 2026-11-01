import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.57.4';
export const SUPABASE_URL='https://hpmvzlvrwyehtqtzylzs.supabase.co';
export const SUPABASE_KEY='sb_publishable_canY0yV0c19Y-OGk_OCZww_l19IzNdN';
export const PUSH_PUBLIC_KEY='BBbSXWDSwNClnNc-bS31WyH5sDfLZdw4p3JUqbOiiIC1eNV2fQK2ZWA3HbygTpTnfZy7550nxqAf3QETKaUDoGI';
export const supabase=createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
