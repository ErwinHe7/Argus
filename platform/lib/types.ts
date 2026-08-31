export type UUID = string;

export type NotificationType = 'agent_reply' | 'like' | 'human_reply';

export type Notification = {
  id: UUID;
  user_id: string;
  type: NotificationType;
  actor_name: string;
  actor_avatar: string | null;
  post_id: UUID | null;
  preview: string;
  read: boolean;
  created_at: string;
};

export type PostAuthorKind = 'human' | 'agent';
export type AutonomousSource = 'manual_trigger' | 'scheduled_post' | 'feed_summary' | 'trade_context';

export type Post = {
  id: UUID;
  author_id: UUID;
  author_name: string;
  author_avatar: string | null;
  content: string;
  images: string[];
  created_at: string;
  reply_count: number;
  like_count: number;
  pinned?: boolean;
  // Autonomous agent fields (added in migration 008)
  author_kind?: PostAuthorKind;
  agent_persona?: string | null;
  is_autonomous?: boolean;
  autonomous_source?: AutonomousSource | null;
};

export type Reply = {
  id: UUID;
  post_id: UUID;
  author_kind: 'human' | 'agent';
  author_id: UUID;
  author_name: string;
  author_avatar: string | null;
  agent_persona: string | null;
  content: string;
  created_at: string;
  confidence_score: number | null;
  visibility: 'public' | 'review' | 'hidden';
  is_autonomous?: boolean;
  up_count: number;
  down_count: number;
};

export type AgentPersona = {
  id: string;
  name: string;
  avatar: string;
  tagline: string;
  system_prompt: string;
  topics: string[];
  /**
   * TokenRouter model slug in `provider/model` form (e.g. `openai/gpt-4o-mini`,
   * `anthropic/claude-haiku-4.5`, `qwen/qwen3.6-plus`). Used by the fan-out
   * flow so each agent can speak through its own LLM.
   */
  model?: string;
  description?: string;
  sub_agents?: { name: string; responsibility: string }[];
};

export type AgentProfileRow = {
  id: string;
  slug: string;
  name: string;
  avatar_url: string | null;
  tagline: string | null;
  system_prompt: string;
  topics: string[];
  reputation_score: number;
};

export type AgentReplyMeta = {
  confidence_score: number;
  critique_notes: string;
};

export type Reaction = {
  id: string;
  reply_id: string;
  user_id: string;
  value: 1 | -1;
  created_at: string;
};

export type ListingCategory = 'furniture' | 'electronics' | 'books' | 'services' | 'tickets' | 'tutoring' | 'other';

export type Listing = {
  id: UUID;
  seller_id: UUID;
  seller_name: string;
  seller_email: string | null;
  seller_contact: string | null;
  category: ListingCategory;
  title: string;
  description: string;
  asking_price_cents: number;
  currency: string;
  location: string | null;
  images: string[];
  status: 'open' | 'pending' | 'sold' | 'withdrawn';
  created_at: string;
  bid_count: number;
  top_bid_cents: number | null;
};

export type Bid = {
  id: UUID;
  listing_id: UUID;
  bidder_id: UUID;
  bidder_name: string;
  bidder_email: string | null;
  bidder_contact: string | null;
  amount_cents: number;
  message: string | null;
  status: 'active' | 'accepted' | 'rejected' | 'withdrawn';
  created_at: string;
};

export type Transaction = {
  id: UUID;
  listing_id: UUID;
  winning_bid_id: UUID;
  seller_id: UUID;
  buyer_id: UUID;
  seller_name: string;
  buyer_name: string;
  seller_email: string | null;
  buyer_email: string | null;
  seller_contact: string | null;
  buyer_contact: string | null;
  amount_cents: number;
  status: 'pending' | 'confirmed' | 'cancelled' | 'completed';
  created_at: string;
};

export type Message = {
  id: UUID;
  transaction_id: UUID;
  sender_id: UUID;
  sender_name: string;
  content: string;
  created_at: string;
};
