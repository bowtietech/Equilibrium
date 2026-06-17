import Supabase

// Shared Supabase client — one instance for the entire app lifetime.
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://bbnpfanmvuvsvzcuaoqj.supabase.co")!,
    supabaseKey: "sb_publishable_d4k5k-yWVwlrmlbso2Iglg_7zRQMo8w"
)
