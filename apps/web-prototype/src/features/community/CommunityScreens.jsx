import { useState, useEffect } from 'react';
import { BookOpen, Bookmark, CheckCircle2, Clock, EyeOff, Flag, Heart, HelpCircle, MapPin, MessageCircle, MoreHorizontal, Plus, Send, Share2, Trash2, UserCheck, UserPlus, Users } from 'lucide-react';
import { Chip, EmptyState, PrimaryButton, SecondaryButton, TopBar } from '../../components/ui';
import { DESTINATIONS, GROUPS, GROUP_RULES, MEMBERS } from '../../data/catalog';
import { COMPOSER_HINT, COMPOSER_TYPES, ME_ID, POST_MAX, POST_MIN, POST_TYPE_META, REPORT_REASONS, destinationGradient, formatCount } from './constants';

export function Avatar({ member, size = 38 }) {
  return (
    <div aria-hidden="true" style={{ width: size, height: size, borderRadius: 999, background: member.color, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: Math.round(size * 0.42), flexShrink: 0 }}>
      {member.initial}
    </div>
  );
}

export function PostAction({ icon: Icon, label, count, pressed, color, onClick, fill }) {
  const isToggle = typeof pressed === 'boolean';
  return (
    <button onClick={onClick} aria-label={label} aria-pressed={isToggle ? pressed : undefined}
      style={{ display: 'flex', alignItems: 'center', gap: 5, background: 'none', border: 'none', cursor: 'pointer', padding: '6px 4px', color: pressed ? color : 'var(--ink-soft)', fontSize: 12, fontWeight: 600 }}>
      <Icon size={18} fill={pressed && fill ? color : 'none'} />
      {count !== undefined && <span>{formatCount(count)}</span>}
    </button>
  );
}

export function PostCard({ post, cm, nav, detail = false, linkAuthor = true }) {
  const author = cm.memberOf(post.authorId);
  const meta = POST_TYPE_META[post.type];
  const TypeIcon = meta.icon;
  const group = post.groupId ? GROUPS.find((g) => g.id === post.groupId) : null;
  const postComments = cm.commentsOf(post.id);
  const isLiked = cm.liked.includes(post.id);
  const isSaved = cm.saved.includes(post.id);
  const hasBest = postComments.some((c) => c.best);
  const tripCopied = cm.copiedTrips.includes(post.id);
  const openPost = () => { if (!detail) { cm.selectPost(post.id); nav.push('post-detail'); } };
  const openAuthor = () => { cm.selectMember(author.id); nav.push('member'); };
  const clamp = detail ? {} : { display: '-webkit-box', WebkitLineClamp: 4, WebkitBoxOrient: 'vertical', overflow: 'hidden' };
  return (
    <article style={{ border: '1px solid var(--border)', borderRadius: 18, background: 'var(--surface)', padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
      <header style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <button onClick={linkAuthor ? openAuthor : undefined} aria-label={`ดูโปรไฟล์ ${author.name}`} disabled={!linkAuthor}
          style={{ display: 'flex', alignItems: 'center', gap: 10, flex: 1, minWidth: 0, background: 'none', border: 'none', padding: 0, cursor: linkAuthor ? 'pointer' : 'default', textAlign: 'left' }}>
          <Avatar member={author} />
          <span style={{ minWidth: 0 }}>
            <span style={{ display: 'block', fontSize: 13, fontWeight: 700, color: 'var(--ink)' }}>{author.name}</span>
            <span style={{ display: 'block', fontSize: 11, color: 'var(--ink-soft)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {author.level} ({post.time})
            </span>
          </span>
        </button>
        <button onClick={() => cm.openSheet({ type: 'post', postId: post.id })} aria-label="ตัวเลือกโพสต์" style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 6, display: 'flex' }}>
          <MoreHorizontal size={18} color="var(--ink-soft)" />
        </button>
      </header>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 11, fontWeight: 700, padding: '4px 10px', borderRadius: 999, background: 'var(--pine-pale)', color: 'var(--pine)' }}>
          <TypeIcon size={12} /> {meta.label}
        </span>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 11, fontWeight: 600, padding: '4px 10px', borderRadius: 999, background: 'var(--muted-bg)', color: 'var(--ink-soft)' }}>
          <MapPin size={11} /> {post.destination}
        </span>
        {group && (
          <span style={{ fontSize: 11, fontWeight: 600, padding: '4px 10px', borderRadius: 999, background: 'var(--muted-bg)', color: 'var(--ink-soft)' }}>{group.name}</span>
        )}
      </div>

      {detail ? (
        <p style={{ fontSize: 14, lineHeight: 1.7, color: 'var(--ink)', whiteSpace: 'pre-wrap' }}>{post.text}</p>
      ) : (
        <button onClick={openPost} style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', textAlign: 'left' }}>
          <span style={{ fontSize: 13.5, lineHeight: 1.65, color: 'var(--ink)', ...clamp }}>{post.text}</span>
        </button>
      )}

      {post.hasImage && (
        <div role="img" aria-label={`ภาพบรรยากาศ ${post.destination}`} style={{ height: 150, borderRadius: 14, background: destinationGradient(post.destination), display: 'flex', alignItems: 'flex-end', padding: 12 }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: '#fff', fontSize: 12, fontWeight: 700 }}><MapPin size={13} /> {post.destination}</span>
        </div>
      )}

      {post.sharedTrip && (
        <div style={{ border: '1px dashed var(--border)', borderRadius: 14, padding: 12, display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)' }}>ทริป{post.destination} {post.sharedTrip.days} วัน</p>
            <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', marginTop: 2 }}>งบประมาณ ฿{post.sharedTrip.budget.toLocaleString()} สไตล์ {post.sharedTrip.styles.join(', ')}</p>
          </div>
          <button onClick={() => cm.copyTrip(post)} disabled={tripCopied}
            style={{ padding: '8px 12px', borderRadius: 12, border: '1.5px solid var(--pine)', background: tripCopied ? 'var(--pine-pale)' : 'transparent', color: 'var(--pine)', fontWeight: 700, fontSize: 12, cursor: tripCopied ? 'default' : 'pointer', flexShrink: 0 }}>
            {tripCopied ? 'บันทึกแล้ว' : 'บันทึกเป็นทริปของฉัน'}
          </button>
        </div>
      )}

      {post.type === 'question' && (
        <span style={{ alignSelf: 'flex-start', display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 11, fontWeight: 700, padding: '4px 10px', borderRadius: 999, background: hasBest ? 'var(--pine-pale)' : 'var(--amber-soft)', color: hasBest ? 'var(--pine)' : 'var(--amber-ink)' }}>
          {hasBest ? <CheckCircle2 size={12} /> : <Clock size={12} />}
          {hasBest ? 'มีคำตอบที่ดีที่สุด' : postComments.length > 0 ? `มี ${postComments.length} คำตอบ` : 'รอคำตอบ'}
        </span>
      )}

      <footer style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderTop: '1px solid var(--border)', paddingTop: 6 }}>
        <div style={{ display: 'flex', gap: 10 }}>
          <PostAction icon={Heart} label={isLiked ? 'ยกเลิกถูกใจ' : 'ถูกใจ'} count={cm.likeCount(post)} pressed={isLiked} color="var(--danger)" fill onClick={() => cm.toggleLike(post.id)} />
          <PostAction icon={MessageCircle} label="ดูความคิดเห็น" count={postComments.length} onClick={openPost} />
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <PostAction icon={Bookmark} label={isSaved ? 'เลิกบันทึกโพสต์' : 'บันทึกโพสต์'} pressed={isSaved} color="var(--pine)" fill onClick={() => cm.toggleSave(post.id)} />
          <PostAction icon={Share2} label="คัดลอกลิงก์โพสต์" onClick={() => cm.sharePost(post.id)} />
        </div>
      </footer>
    </article>
  );
}

export function FollowButton({ cm, memberId, compact = false }) {
  const isFollowing = cm.following.includes(memberId);
  return (
    <button onClick={() => cm.toggleFollow(memberId)} aria-pressed={isFollowing}
      style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 5, padding: compact ? '7px 12px' : '10px 18px', borderRadius: 999, fontSize: 12, fontWeight: 700, cursor: 'pointer', border: '1.5px solid var(--pine)', background: isFollowing ? 'transparent' : 'var(--pine)', color: isFollowing ? 'var(--pine)' : '#fff' }}>
      {isFollowing ? <UserCheck size={14} /> : <UserPlus size={14} />}
      {isFollowing ? 'กำลังติดตาม' : 'ติดตาม'}
    </button>
  );
}

export function SuggestedMembers({ cm, nav }) {
  const list = MEMBERS.filter((m) => m.id !== ME_ID && !cm.following.includes(m.id));
  if (list.length === 0) return null;
  return (
    <section aria-label="แนะนำให้ติดตาม">
      <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>แนะนำให้ติดตาม</p>
      <div className="scrollbar-hide" style={{ display: 'flex', gap: 10, overflowX: 'auto' }}>
        {list.map((m) => (
          <div key={m.id} style={{ flex: '0 0 148px', border: '1px solid var(--border)', borderRadius: 16, background: 'var(--surface)', padding: 12, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, textAlign: 'center' }}>
            <button onClick={() => { cm.selectMember(m.id); nav.push('member'); }} aria-label={`ดูโปรไฟล์ ${m.name}`} style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
              <Avatar member={m} size={46} />
              <span style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--ink)' }}>{m.name}</span>
              <span style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}>{m.level}</span>
            </button>
            <FollowButton cm={cm} memberId={m.id} compact />
          </div>
        ))}
      </div>
    </section>
  );
}

export function FeedView({ cm, nav }) {
  const { feedMode, dest } = cm.ui;
  const destinations = ['ทั้งหมด', ...DESTINATIONS.map((d) => d.name)];
  let list = cm.visiblePosts;
  if (feedMode === 'following') list = list.filter((p) => cm.following.includes(p.authorId));
  if (dest !== 'ทั้งหมด') list = list.filter((p) => p.destination === dest);
  return (
    <>
      <div style={{ display: 'flex', gap: 8 }}>
        <Chip label="สำหรับคุณ" active={feedMode === 'all'} onClick={() => cm.setUi({ feedMode: 'all' })} />
        <Chip label="กำลังติดตาม" active={feedMode === 'following'} onClick={() => cm.setUi({ feedMode: 'following' })} />
      </div>
      <div className="scrollbar-hide" style={{ display: 'flex', gap: 8, overflowX: 'auto' }}>
        {destinations.map((d) => <Chip key={d} label={d} active={dest === d} onClick={() => cm.setUi({ dest: d })} />)}
      </div>
      {feedMode === 'all' && dest === 'ทั้งหมด' && <SuggestedMembers cm={cm} nav={nav} />}
      {list.length === 0 ? (
        feedMode === 'following' ? (
          <EmptyState icon={Users} title="ยังไม่มีโพสต์จากคนที่คุณติดตาม" hint="ติดตามนักเดินทางที่ชอบสไตล์เดียวกัน แล้วโพสต์ของพวกเขาจะมาอยู่ที่นี่"
            action={<div style={{ width: 200 }}><PrimaryButton onClick={() => cm.setUi({ feedMode: 'all' })}>ดูโพสต์ทั้งหมด</PrimaryButton></div>} />
        ) : (
          <EmptyState icon={BookOpen} title={`ยังไม่มีโพสต์เกี่ยวกับ${dest}`} hint="เป็นคนแรกที่แบ่งปันประสบการณ์ของคุณ"
            action={<div style={{ width: 200 }}><PrimaryButton onClick={() => { cm.startPost({}); nav.push('create-post'); }}>เขียนโพสต์</PrimaryButton></div>} />
        )
      ) : (
        list.map((p) => <PostCard key={p.id} post={p} cm={cm} nav={nav} />)
      )}
    </>
  );
}

export function QaView({ cm, nav }) {
  const { qaFilter } = cm.ui;
  const questions = cm.visiblePosts.filter((p) => p.type === 'question');
  const answered = (p) => cm.commentsOf(p.id).length > 0;
  const list = questions.filter((p) => qaFilter === 'all' || (qaFilter === 'answered' ? answered(p) : !answered(p)));
  return (
    <>
      <PrimaryButton onClick={() => { cm.startPost({ type: 'question' }); nav.push('create-post'); }}>ถามคำถามใหม่</PrimaryButton>
      <div style={{ display: 'flex', gap: 8 }}>
        <Chip label="ทั้งหมด" active={qaFilter === 'all'} onClick={() => cm.setUi({ qaFilter: 'all' })} />
        <Chip label="รอคำตอบ" active={qaFilter === 'open'} onClick={() => cm.setUi({ qaFilter: 'open' })} />
        <Chip label="มีคำตอบแล้ว" active={qaFilter === 'answered'} onClick={() => cm.setUi({ qaFilter: 'answered' })} />
      </div>
      {list.length === 0
        ? <EmptyState icon={HelpCircle} title="ไม่มีคำถามในหมวดนี้" hint="ลองเปลี่ยนตัวกรอง หรือถามคำถามที่คุณสงสัย" />
        : list.map((p) => <PostCard key={p.id} post={p} cm={cm} nav={nav} />)}
    </>
  );
}

export function GroupRow({ group, cm, nav }) {
  const isJoined = cm.joined.includes(group.id);
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, border: '1px solid var(--border)', borderRadius: 16, background: 'var(--surface)', padding: 12 }}>
      <button onClick={() => { cm.selectGroup(group.id); nav.push('group-detail'); }} aria-label={`เปิดกลุ่ม ${group.name}`}
        style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0, background: 'none', border: 'none', padding: 0, cursor: 'pointer', textAlign: 'left' }}>
        <div aria-hidden="true" style={{ width: 46, height: 46, borderRadius: 14, background: group.gradient, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Users size={20} color="#fff" />
        </div>
        <span style={{ minWidth: 0 }}>
          <span style={{ display: 'block', fontSize: 13.5, fontWeight: 700, color: 'var(--ink)' }}>{group.name}</span>
          <span style={{ display: 'block', fontSize: 11, color: 'var(--ink-soft)', marginTop: 2 }}>สมาชิก {cm.memberCount(group).toLocaleString()} คน</span>
        </span>
      </button>
      <button onClick={() => cm.toggleJoin(group.id)} aria-pressed={isJoined}
        style={{ padding: '8px 14px', borderRadius: 999, fontSize: 12, fontWeight: 700, cursor: 'pointer', flexShrink: 0, border: '1.5px solid var(--pine)', background: isJoined ? 'transparent' : 'var(--pine)', color: isJoined ? 'var(--pine)' : '#fff' }}>
        {isJoined ? 'เข้าร่วมแล้ว' : 'เข้าร่วม'}
      </button>
    </div>
  );
}

export function GroupsView({ cm, nav }) {
  const mine = GROUPS.filter((g) => cm.joined.includes(g.id));
  const others = GROUPS.filter((g) => !cm.joined.includes(g.id));
  return (
    <>
      <section>
        <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>กลุ่มของฉัน</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {mine.length === 0
            ? <p style={{ fontSize: 12.5, color: 'var(--ink-soft)' }}>คุณยังไม่ได้เข้าร่วมกลุ่มใด เลือกกลุ่มที่สนใจจากรายการด้านล่าง</p>
            : mine.map((g) => <GroupRow key={g.id} group={g} cm={cm} nav={nav} />)}
        </div>
      </section>
      {others.length > 0 && (
        <section>
          <p className="font-display" style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>กลุ่มแนะนำ</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {others.map((g) => <GroupRow key={g.id} group={g} cm={cm} nav={nav} />)}
          </div>
        </section>
      )}
    </>
  );
}

export function CommunityScreen({ cm, nav }) {
  const tabs = [{ id: 'feed', label: 'ฟีด' }, { id: 'qa', label: 'ถาม-ตอบ' }, { id: 'groups', label: 'กลุ่ม' }];
  const tab = cm.ui.tab;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 20px 0', flexShrink: 0 }}>
        <h1 className="font-display" style={{ fontSize: 20, fontWeight: 600, color: 'var(--ink)' }}>ชุมชน</h1>
        <button onClick={() => { cm.startPost({}); nav.push('create-post'); }} aria-label="สร้างโพสต์ใหม่"
          style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '9px 14px', borderRadius: 999, border: 'none', background: 'var(--pine)', color: '#fff', fontWeight: 700, fontSize: 12.5, cursor: 'pointer' }}>
          <Plus size={15} /> โพสต์
        </button>
      </div>
      <div role="tablist" aria-label="หมวดชุมชน" style={{ display: 'flex', borderBottom: '1px solid var(--border)', margin: '12px 20px 0', flexShrink: 0 }}>
        {tabs.map((t) => (
          <button key={t.id} role="tab" aria-selected={tab === t.id} onClick={() => cm.setUi({ tab: t.id })}
            style={{ flex: 1, padding: '10px 0', background: 'none', border: 'none', borderBottom: tab === t.id ? '2.5px solid var(--pine)' : '2.5px solid transparent', color: tab === t.id ? 'var(--pine)' : 'var(--ink-soft)', fontWeight: tab === t.id ? 700 : 500, fontSize: 13.5, cursor: 'pointer', marginBottom: -1 }}>
            {t.label}
          </button>
        ))}
      </div>
      <div className="scrollbar-hide" role="tabpanel" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '14px 20px 20px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {tab === 'feed' && <FeedView cm={cm} nav={nav} />}
        {tab === 'qa' && <QaView cm={cm} nav={nav} />}
        {tab === 'groups' && <GroupsView cm={cm} nav={nav} />}
      </div>
    </div>
  );
}

export function CommentItem({ comment, post, cm }) {
  const author = cm.memberOf(comment.authorId);
  const isPostAuthor = comment.authorId === post.authorId;
  const isLiked = cm.likedComments.includes(comment.id);
  const canMarkBest = post.type === 'question' && post.authorId === ME_ID && comment.authorId !== ME_ID;
  return (
    <div style={{ display: 'flex', gap: 10, padding: '12px 0', borderBottom: '1px solid var(--border)' }}>
      <Avatar member={author} size={32} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 6 }}>
          <span style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--ink)' }}>{author.name}</span>
          {isPostAuthor && <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 999, background: 'var(--muted-bg)', color: 'var(--ink-soft)' }}>เจ้าของโพสต์</span>}
          {comment.best && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 999, background: 'var(--pine-pale)', color: 'var(--pine)' }}><CheckCircle2 size={11} /> คำตอบที่ดีที่สุด</span>}
          <span style={{ fontSize: 10.5, color: 'var(--ink-soft)' }}>{comment.time}</span>
        </div>
        <p style={{ fontSize: 13, lineHeight: 1.6, color: 'var(--ink)', margin: '4px 0 6px', whiteSpace: 'pre-wrap' }}>{comment.text}</p>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <button onClick={() => cm.toggleCommentLike(comment.id)} aria-pressed={isLiked} aria-label={isLiked ? 'ยกเลิกถูกใจความคิดเห็น' : 'ถูกใจความคิดเห็น'}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 4, background: 'none', border: 'none', cursor: 'pointer', padding: 0, fontSize: 11.5, fontWeight: 600, color: isLiked ? 'var(--danger)' : 'var(--ink-soft)' }}>
            <Heart size={14} fill={isLiked ? 'var(--danger)' : 'none'} /> {comment.likes + (isLiked ? 1 : 0)}
          </button>
          {canMarkBest && (
            <button onClick={() => cm.markBest(post.id, comment.id)}
              style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 0, fontSize: 11.5, fontWeight: 700, color: 'var(--pine)' }}>
              {comment.best ? 'ยกเลิกคำตอบที่ดีที่สุด' : 'เลือกเป็นคำตอบที่ดีที่สุด'}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

export function PostDetailScreen({ cm, nav }) {
  const [text, setText] = useState('');
  const post = cm.visiblePosts.find((p) => p.id === cm.selected.postId) || null;
  // eslint-disable-next-line react-hooks/exhaustive-deps -- nav is recreated every render; only a post disappearing should trigger the pop
  useEffect(() => { if (!post) nav.pop(); }, [post]);
  if (!post) return null;
  const list = [...cm.commentsOf(post.id)].sort((a, b) => (b.best ? 1 : 0) - (a.best ? 1 : 0));
  const submit = () => {
    if (!text.trim()) return;
    cm.addComment(post.id, text);
    setText('');
  };
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="โพสต์" onBack={nav.pop} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20 }}>
        <PostCard post={post} cm={cm} nav={nav} detail />
        <p className="font-display" style={{ fontSize: 15, fontWeight: 600, margin: '20px 0 2px' }}>
          {post.type === 'question' ? 'คำตอบ' : 'ความคิดเห็น'} ({list.length})
        </p>
        {list.length === 0
          ? <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', padding: '16px 0' }}>{post.type === 'question' ? 'ยังไม่มีคำตอบ เป็นคนแรกที่ช่วยตอบคำถามนี้' : 'ยังไม่มีความคิดเห็น เริ่มบทสนทนาได้เลย'}</p>
          : list.map((c) => <CommentItem key={c.id} comment={c} post={post} cm={cm} />)}
      </div>
      <form onSubmit={(e) => { e.preventDefault(); submit(); }} style={{ display: 'flex', gap: 8, padding: '12px 20px', borderTop: '1px solid var(--border)', flexShrink: 0, background: 'var(--surface)' }}>
        <input value={text} onChange={(e) => setText(e.target.value)} maxLength={300} aria-label={post.type === 'question' ? 'เขียนคำตอบ' : 'เขียนความคิดเห็น'}
          placeholder={post.type === 'question' ? 'เขียนคำตอบของคุณ' : 'เขียนความคิดเห็น'}
          style={{ flex: 1, minWidth: 0, border: '1.5px solid var(--border)', borderRadius: 999, padding: '10px 16px', fontSize: 13.5, fontFamily: "'Plus Jakarta Sans', sans-serif", background: 'var(--paper)', color: 'var(--ink)', outline: 'none' }} />
        <button type="submit" disabled={!text.trim()} aria-label="ส่ง"
          style={{ width: 42, height: 42, borderRadius: 999, border: 'none', background: text.trim() ? 'var(--pine)' : 'var(--disabled)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: text.trim() ? 'pointer' : 'default', flexShrink: 0 }}>
          <Send size={17} color="#fff" />
        </button>
      </form>
    </div>
  );
}

export function CreatePostScreen({ cm, nav }) {
  const c = cm.composer;
  const len = c.text.trim().length;
  const valid = len >= POST_MIN && len <= POST_MAX && !!c.destination;
  const myGroups = GROUPS.filter((g) => cm.joined.includes(g.id));
  const submit = () => { if (cm.createPost()) nav.pop(); };
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="สร้างโพสต์" onBack={nav.pop} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>ประเภทโพสต์</p>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {COMPOSER_TYPES.map((t) => <Chip key={t} label={POST_TYPE_META[t].label} active={c.type === t} onClick={() => cm.updateComposer({ type: t })} />)}
          </div>
        </div>
        <div>
          <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>จุดหมายที่เกี่ยวข้อง</p>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {[...DESTINATIONS.map((d) => d.name), 'ปาย'].filter((v, i, a) => a.indexOf(v) === i).map((d) => (
              <Chip key={d} label={d} active={c.destination === d} onClick={() => cm.updateComposer({ destination: d })} />
            ))}
          </div>
        </div>
        {myGroups.length > 0 && (
          <div>
            <p style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>โพสต์ในกลุ่ม (ไม่บังคับ)</p>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <Chip label="ไม่ระบุกลุ่ม" active={!c.groupId} onClick={() => cm.updateComposer({ groupId: null })} />
              {myGroups.map((g) => <Chip key={g.id} label={g.name} active={c.groupId === g.id} onClick={() => cm.updateComposer({ groupId: g.id })} />)}
            </div>
          </div>
        )}
        <div>
          <label htmlFor="post-text" style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 10 }}>เนื้อหา</label>
          <textarea id="post-text" rows={6} maxLength={POST_MAX} value={c.text} onChange={(e) => cm.updateComposer({ text: e.target.value })} placeholder={COMPOSER_HINT[c.type]}
            style={{ width: '100%', border: '1.5px solid var(--border)', borderRadius: 14, padding: '12px 14px', fontSize: 13.5, lineHeight: 1.6, fontFamily: "'Plus Jakarta Sans', sans-serif", color: 'var(--ink)', background: 'var(--surface)', outline: 'none', resize: 'none' }} />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontSize: 11.5, color: 'var(--ink-soft)' }}>
            <span>{len > 0 && len < POST_MIN ? `พิมพ์อีก ${POST_MIN - len} ตัวอักษร` : ''}</span>
            <span>{c.text.length}/{POST_MAX}</span>
          </div>
        </div>
        <div style={{ borderRadius: 14, background: 'var(--pine-pale)', padding: 14 }}>
          <p style={{ fontSize: 12, fontWeight: 700, color: 'var(--pine)', marginBottom: 6 }}>แนวทางของชุมชน</p>
          {GROUP_RULES.map((r) => <p key={r} style={{ fontSize: 11.5, color: 'var(--ink-soft)', lineHeight: 1.6 }}>{r}</p>)}
        </div>
      </div>
      <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', flexShrink: 0 }}>
        <PrimaryButton onClick={submit} disabled={!valid}>โพสต์</PrimaryButton>
        {!c.destination && <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', textAlign: 'center', marginTop: 8 }}>เลือกจุดหมายที่เกี่ยวข้องก่อนโพสต์</p>}
      </div>
    </div>
  );
}

export function MemberScreen({ cm, nav }) {
  const [tab, setTab] = useState('posts');
  const member = cm.memberOf(cm.selected.memberId || ME_ID);
  const isMe = member.id === ME_ID;
  const posts = cm.visiblePosts.filter((p) => p.authorId === member.id);
  const savedPosts = cm.visiblePosts.filter((p) => cm.saved.includes(p.id));
  const list = tab === 'saved' ? savedPosts : posts;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title={isMe ? 'ชุมชนของฉัน' : 'โปรไฟล์'} onBack={nav.pop} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, textAlign: 'center' }}>
          <Avatar member={member} size={72} />
          <p className="font-display" style={{ fontSize: 18, fontWeight: 600, color: 'var(--ink)' }}>{member.name}</p>
          <p style={{ fontSize: 12, fontWeight: 600, color: 'var(--pine)' }}>{member.level}</p>
          <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', lineHeight: 1.6, maxWidth: 260 }}>{member.bio}</p>
        </div>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 28 }}>
          <div style={{ textAlign: 'center' }}><p style={{ fontSize: 16, fontWeight: 700 }}>{posts.length}</p><p style={{ fontSize: 11, color: 'var(--ink-soft)' }}>โพสต์</p></div>
          <div style={{ textAlign: 'center' }}><p style={{ fontSize: 16, fontWeight: 700 }}>{formatCount(cm.followerCount(member))}</p><p style={{ fontSize: 11, color: 'var(--ink-soft)' }}>ผู้ติดตาม</p></div>
        </div>
        {!isMe && <div style={{ alignSelf: 'center' }}><FollowButton cm={cm} memberId={member.id} /></div>}
        {isMe && (
          <div style={{ display: 'flex', gap: 8, justifyContent: 'center' }}>
            <Chip label="โพสต์ของฉัน" active={tab === 'posts'} onClick={() => setTab('posts')} />
            <Chip label="ที่บันทึกไว้" active={tab === 'saved'} onClick={() => setTab('saved')} />
          </div>
        )}
        {list.length === 0
          ? <EmptyState icon={tab === 'saved' ? Bookmark : BookOpen} title={tab === 'saved' ? 'ยังไม่มีโพสต์ที่บันทึกไว้' : 'ยังไม่มีโพสต์'} hint={tab === 'saved' ? 'กดไอคอนบุ๊กมาร์กที่โพสต์เพื่อเก็บไว้อ่านทีหลัง' : isMe ? 'แบ่งปันประสบการณ์การเดินทางครั้งแรกของคุณ' : undefined}
              action={isMe && tab === 'posts' ? <div style={{ width: 200 }}><PrimaryButton onClick={() => { cm.startPost({}); nav.push('create-post'); }}>เขียนโพสต์</PrimaryButton></div> : undefined} />
          : list.map((p) => <PostCard key={p.id} post={p} cm={cm} nav={nav} linkAuthor={tab === 'saved' || p.authorId !== member.id} />)}
      </div>
    </div>
  );
}

export function GroupDetailScreen({ cm, nav }) {
  const group = GROUPS.find((g) => g.id === cm.selected.groupId);
  if (!group) return null;
  const isJoined = cm.joined.includes(group.id);
  const list = cm.visiblePosts.filter((p) => p.groupId === group.id);
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <TopBar title="กลุ่ม" onBack={nav.pop} />
      <div className="scrollbar-hide" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
        <div style={{ height: 120, background: group.gradient, display: 'flex', alignItems: 'flex-end', padding: 18 }}>
          <p className="font-display" style={{ color: '#fff', fontSize: 20, fontWeight: 600 }}>{group.name}</p>
        </div>
        <div style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 16 }}>
          <p style={{ fontSize: 13, lineHeight: 1.7, color: 'var(--ink)' }}>{group.desc}</p>
          <p style={{ fontSize: 12, color: 'var(--ink-soft)' }}>สมาชิก {cm.memberCount(group).toLocaleString()} คน</p>
          <div style={{ display: 'flex', gap: 10 }}>
            <div style={{ flex: 1 }}>
              {isJoined ? <SecondaryButton onClick={() => cm.toggleJoin(group.id)}>ออกจากกลุ่ม</SecondaryButton> : <PrimaryButton onClick={() => cm.toggleJoin(group.id)}>เข้าร่วมกลุ่ม</PrimaryButton>}
            </div>
            {isJoined && (
              <div style={{ flex: 1 }}><PrimaryButton onClick={() => { cm.startPost({ groupId: group.id }); nav.push('create-post'); }}>เขียนโพสต์</PrimaryButton></div>
            )}
          </div>
          <div style={{ borderRadius: 14, background: 'var(--pine-pale)', padding: 14 }}>
            <p style={{ fontSize: 12, fontWeight: 700, color: 'var(--pine)', marginBottom: 6 }}>กฎของกลุ่ม</p>
            {group.rules.map((r) => <p key={r} style={{ fontSize: 11.5, color: 'var(--ink-soft)', lineHeight: 1.6 }}>{r}</p>)}
          </div>
          <p className="font-display" style={{ fontSize: 15, fontWeight: 600 }}>โพสต์ในกลุ่ม</p>
          {list.length === 0
            ? <EmptyState icon={BookOpen} title="ยังไม่มีโพสต์ในกลุ่มนี้" hint={isJoined ? 'เริ่มบทสนทนาแรกของกลุ่ม' : 'เข้าร่วมกลุ่มเพื่อเริ่มโพสต์'} />
            : list.map((p) => <PostCard key={p.id} post={p} cm={cm} nav={nav} />)}
        </div>
      </div>
    </div>
  );
}

export function SheetButton({ icon: Icon, label, onClick, danger }) {
  return (
    <button onClick={onClick} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 12, padding: '14px 4px', background: 'none', border: 'none', borderBottom: '1px solid var(--border)', cursor: 'pointer', textAlign: 'left', color: danger ? 'var(--danger)' : 'var(--ink)', fontSize: 14, fontWeight: 600 }}>
      {Icon && <Icon size={18} />} {label}
    </button>
  );
}

export function CommunitySheet({ cm }) {
  const sheet = cm.sheet;
  useEffect(() => {
    if (!sheet) return undefined;
    const onKey = (e) => { if (e.key === 'Escape') cm.closeSheet(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [sheet, cm]);
  if (!sheet) return null;
  const post = cm.postById(sheet.postId);
  if (!post) return null;
  const isMine = post.authorId === ME_ID;
  const author = cm.memberOf(post.authorId);
  const close = cm.closeSheet;
  let title = 'ตัวเลือกโพสต์';
  let body;
  if (sheet.type === 'post') {
    const isSaved = cm.saved.includes(post.id);
    body = (
      <>
        <SheetButton icon={Bookmark} label={isSaved ? 'เลิกบันทึกโพสต์' : 'บันทึกโพสต์'} onClick={() => { cm.toggleSave(post.id); close(); }} />
        {!isMine && <SheetButton icon={cm.following.includes(author.id) ? UserCheck : UserPlus} label={cm.following.includes(author.id) ? `เลิกติดตาม ${author.name}` : `ติดตาม ${author.name}`} onClick={() => { cm.toggleFollow(author.id); close(); }} />}
        {!isMine && <SheetButton icon={EyeOff} label="ซ่อนโพสต์นี้" onClick={() => { cm.hidePost(post.id); close(); }} />}
        {!isMine && <SheetButton icon={Flag} label="รายงานโพสต์" danger onClick={() => cm.openSheet({ type: 'report', postId: post.id })} />}
        {isMine && <SheetButton icon={Trash2} label="ลบโพสต์" danger onClick={() => cm.openSheet({ type: 'delete', postId: post.id })} />}
      </>
    );
  } else if (sheet.type === 'report') {
    title = 'รายงานโพสต์';
    body = (
      <>
        <p style={{ fontSize: 12, color: 'var(--ink-soft)', marginBottom: 4 }}>เลือกเหตุผลที่ตรงที่สุด ทีมงานจะตรวจสอบและโพสต์นี้จะถูกซ่อนจากฟีดของคุณ</p>
        {REPORT_REASONS.map((r) => <SheetButton key={r} label={r} onClick={() => { cm.reportPost(post.id); close(); }} />)}
      </>
    );
  } else {
    title = 'ลบโพสต์นี้?';
    body = (
      <>
        <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', lineHeight: 1.6, marginBottom: 14 }}>โพสต์และความคิดเห็นทั้งหมดจะถูกลบและไม่สามารถกู้คืนได้</p>
        <div style={{ display: 'flex', gap: 10 }}>
          <div style={{ flex: 1 }}><SecondaryButton onClick={close}>ยกเลิก</SecondaryButton></div>
          <button onClick={() => { cm.deletePost(post.id); close(); }} style={{ flex: 1, padding: 15, borderRadius: 16, border: 'none', background: 'var(--danger)', color: '#fff', fontWeight: 700, fontSize: 15, cursor: 'pointer' }}>ลบโพสต์</button>
        </div>
      </>
    );
  }
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 60, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
      <div onClick={close} aria-hidden="true" style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.45)' }} />
      <div role="dialog" aria-modal="true" aria-label={title} className="fade-up" style={{ position: 'relative', background: 'var(--surface)', borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: '16px 20px 28px' }}>
        <div style={{ width: 40, height: 4, borderRadius: 999, background: 'var(--border)', margin: '0 auto 12px' }} />
        <p className="font-display" style={{ fontSize: 16, fontWeight: 600, marginBottom: 6 }}>{title}</p>
        {body}
      </div>
    </div>
  );
}
