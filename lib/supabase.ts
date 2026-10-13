import {createClient, SupabaseClient} from '@supabase/supabase-js';
let client:SupabaseClient|null=null;
export function supabase(){const url=process.env.NEXT_PUBLIC_SUPABASE_URL, key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;if(!url||!key)return null;return client??(client=createClient(url,key,{auth:{persistSession:true,autoRefreshToken:true}}))}
export type Profile={id:string;display_name:string;role:'admin'|'member';active:boolean;created_at:string};
export type Match={id:string;league:string;home_team:string;away_team:string;kickoff_at:string;deadline_at:string;home_goals:number|null;away_goals:number|null;created_at:string};
export type Prediction={id:string;match_id:string;user_id:string;p_home:number;p_draw:number;p_away:number;created_at:string;updated_at:string};
export function score(p:Prediction,m:Match){if(m.home_goals===null||m.away_goals===null)return null;const idx=m.home_goals>m.away_goals?0:m.home_goals===m.away_goals?1:2;return [p.p_home,p.p_draw,p.p_away].reduce((a,v,i)=>a+(v/100-(idx===i?1:0))**2,0)}
export function outcome(m:Match){return m.home_goals===null||m.away_goals===null?'Pending':m.home_goals>m.away_goals?'Home Win':m.home_goals===m.away_goals?'Draw':'Away Win'}
export const fmt=(s:string)=>new Date(s).toLocaleString('en-GB',{day:'numeric',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit',timeZone:'Asia/Jakarta'});
