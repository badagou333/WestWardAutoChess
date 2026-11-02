import struct,sys,json
from pathlib import Path
p=Path(sys.argv[1]); d=p.read_bytes()
def u32(pos): return struct.unpack_from('>I',d,pos)[0]
def s32(pos): return struct.unpack_from('>i',d,pos)[0]
def u64(pos): return struct.unpack_from('>Q',d,pos)[0]
def s64(pos): return struct.unpack_from('>q',d,pos)[0]
def atoms(lo,hi):
 while lo+8<=hi:
  n=u32(lo);typ=d[lo+4:lo+8].decode('ascii','replace'); hdr=8
  if n==1:n=u64(lo+8);hdr=16
  if n==0:n=hi-lo
  if n<hdr or lo+n>hi:raise ValueError((lo,n,typ,hi))
  yield typ,lo+hdr,lo+n
  lo+=n
def child(parent,name): return next(((a,b) for t,a,b in atoms(*parent) if t==name),None)
def decode_header(ab):
 a,b=ab; version=d[a]; q=a+4
 if version==0:return {'version':version,'timescale':u32(q+8),'duration':u32(q+12)}
 return {'version':version,'timescale':u32(q+16),'duration':u64(q+20)}
moov=child((0,len(d)),'moov'); mvhd=decode_header(child(moov,'mvhd')); tracks=[]
for t,a,b in atoms(*moov):
 if t!='trak':continue
 tr=(a,b); mdia=child(tr,'mdia'); mdhd=decode_header(child(mdia,'mdhd')); hdlr=child(mdia,'hdlr'); kind=d[hdlr[0]+8:hdlr[0]+12].decode('ascii','replace')
 edts=child(tr,'edts'); ed=child(edts,'elst') if edts else None; edits=[]
 if ed:
  q=ed[0]; vers=d[q]; cnt=u32(q+4); q+=8
  for _ in range(cnt):
   if vers==1: dur=u64(q);mt=s64(q+8);q+=16
   else:dur=u32(q);mt=s32(q+4);q+=8
   r=struct.unpack_from('>hh',d,q);q+=4; edits.append({'segment_duration_movie_ticks':dur,'segment_duration_s':dur/mvhd['timescale'],'media_time_track_ticks':mt,'media_time_s':mt/mdhd['timescale'] if mt>=0 else None,'rate':list(r)})
 stbl=child(child(mdia,'minf'),'stbl'); stts=child(stbl,'stts'); q=stts[0]; cnt=u32(q+4);q+=8; entries=[]
 for _ in range(cnt): entries.append((u32(q),u32(q+4)));q+=8
 ctts=child(stbl,'ctts'); ctts_info=None
 if ctts:
  q=ctts[0]; v=d[q]; cnt=u32(q+4);q+=8; offsets=[]
  for _ in range(cnt): offsets.append((u32(q),s32(q+4) if v else u32(q+4)));q+=8
  ctts_info={'version':v,'entries':offsets}
 s=[delta for count,delta in entries for _ in range(count)]; end=sum(s); laststart=end-s[-1]
 tracks.append({'handler':kind,'media_header':mdhd,'edit_list':edits,'stts_entry_count':len(entries),'stts_count':len(s),'stts_duration_sum':end,'stts_duration_seconds':end/mdhd['timescale'],'last_5_sample_durations':s[-5:],'last_sample_duration_seconds':s[-1]/mdhd['timescale'],'last_decode_start_ticks':laststart,'last_decode_start_seconds':laststart/mdhd['timescale'],'ctts':ctts_info,'last_entries':entries[-8:]})
r={'file':str(p),'movie_header':mvhd,'tracks':tracks}; print(json.dumps(r,ensure_ascii=False,indent=2))
