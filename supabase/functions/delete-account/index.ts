// ============================================================================
//  delete-account — 계정 영구 삭제
//
//  배포:  supabase functions deploy delete-account
//  ⚠ --no-verify-jwt 를 붙이지 마세요. 붙이면 누구나 이 함수를 부를 수 있습니다.
//
//  ## 왜 Edge Function 이 필요한가
//
//  `supabase.auth` 클라이언트에는 "내 계정을 지운다"가 **없습니다.** 유저 삭제는
//  service_role 키가 있어야 하는 admin API 이고, 그 키는 앱 번들에 절대 들어가면
//  안 됩니다(APK 를 풀면 나옵니다. 그 키 하나로 전 사용자 데이터가 열립니다).
//
//  ## App Store Guideline 5.1.1(v)
//
//  계정을 만들 수 있는 앱은 **앱 안에서** 계정을 영구 삭제할 수 있어야 합니다.
//  비활성화만 제공하면 리젝입니다. auth.admin.deleteUser 는 진짜 삭제이고,
//  profiles / folders / tickets / ticket_counters 가 on delete cascade 로 물려
//  있어서 같이 사라집니다. 스토리지만 cascade 가 없으므로 여기서 직접 지웁니다.
// ============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) return json({ error: 'unauthorized' }, 401);

  const url = Deno.env.get('SUPABASE_URL')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

  // 1. 호출자가 누구인지 **그 사람의 토큰으로** 확인합니다.
  //    body 로 받은 user_id 를 믿으면 남의 계정을 지울 수 있습니다.
  const asUser = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: whoErr } = await asUser.auth.getUser();
  if (whoErr || !user) return json({ error: 'unauthorized' }, 401);

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Remove every page, always reading from offset zero after each deletion.
  // Do not claim deletion succeeded while private photos remain in storage.
  try {
    while (true) {
      const { data: files, error: listError } = await admin.storage
        .from('posters').list(user.id, { limit: 100 });
      if (listError) throw listError;
      if (!files?.length) break;
      const { error: removeError } = await admin.storage.from('posters')
        .remove(files.map((f) => `${user.id}/${f.name}`));
      if (removeError) throw removeError;
    }
  } catch (e) {
    console.error('poster cleanup failed', user.id, e);
    return json({ error: 'photo_cleanup_failed' }, 503);
  }

  // 3. 계정. 나머지 테이블이 cascade 로 따라갑니다.
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    console.error('deleteUser failed', user.id, error);
    return json({ error: 'delete_failed' }, 500);
  }

  return json({ ok: true });
});