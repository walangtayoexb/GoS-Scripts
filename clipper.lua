
local ffi = require'ffi'
local C = ffi.load(COMMON_PATH .. './clipper')

ffi.cdef[[

// Replace `int64_t` with `int32_t` if Clipper has been compiled with `use_int32`
typedef struct __cl_int_point { int64_t x, y; } cl_int_point;
typedef struct __cl_int_rect { int64_t left; int64_t top; int64_t right; int64_t bottom; } cl_int_rect;
// Replace `long long` with `int` if compiled with `use_int32`
typedef signed long long cInt;

typedef struct __cl_path cl_path;
typedef struct __cl_paths cl_paths;
typedef struct __cl_offset cl_offset;
typedef struct __cl_clipper cl_clipper;

const char* cl_err_msg();

// Path
cl_path* cl_path_new();
void cl_path_free(cl_path *self);
cl_int_point* cl_path_get(cl_path *self, int i);
bool cl_path_add(cl_path *self, cInt x, cInt y);
int cl_path_size(cl_path *self);
double cl_path_area(const cl_path *self);
bool cl_path_orientation(const cl_path *self);
void cl_path_reverse(cl_path *self);
int cl_path_point_in_polygon(cl_path *self,cInt x, cInt y);
cl_paths* cl_path_simplify(cl_path *self,int fillType);
cl_path* cl_path_clean_polygon(const cl_path *in, double distance);

// Paths
cl_paths* cl_paths_new();
void cl_paths_free(cl_paths *self);
cl_path* cl_paths_get(cl_paths *self, int i);
bool cl_paths_add(cl_paths *self, cl_path *path);
int cl_paths_size(cl_paths *self);

// ClipperOffset
cl_offset* cl_offset_new(double miterLimit,double roundPrecision);
void cl_offset_free(cl_offset *self);
cl_paths* cl_offset_path(cl_offset *self, cl_path *subj, double delta, int jointType, int endType);
cl_paths* cl_offset_paths(cl_offset *self, cl_paths *subj, double delta, int jointType, int endType);
void cl_offset_clear(cl_offset *self);

// Clipper
cl_clipper* cl_clipper_new();
void cl_clipper_free(cl_clipper *cl);
void cl_clipper_clear(cl_clipper *cl);
bool cl_clipper_add_path(cl_clipper *cl,cl_path *path, int pt, bool closed,const char *err);
bool cl_clipper_add_paths(cl_clipper *cl,cl_paths *paths, int pt, bool closed,const char *err);
void cl_clipper_reverse_solution(cl_clipper *cl, bool value);
void cl_clipper_preserve_collinear(cl_clipper *cl, bool value);
void cl_clipper_strictly_simple(cl_clipper *cl, bool value);
cl_paths* cl_clipper_execute(cl_clipper *cl,int clipType,int subjFillType,int clipFillType);
cl_int_rect cl_clipper_get_bounds(cl_clipper *cl);
]]

local ClipType  = {
	intersection = 0, union = 1, difference = 2, xor = 3
}

local JoinType = {
	square = 0, round = 1, miter = 2
}

local EndType = {
	closedPolygon = 0, closedLine = 1, openButt = 2, openSquare = 3, openRound = 4
}

local InitOptions = {
	reverseSolution  = 1, strictlySimple   = 2, preserveCollinear = 4
}

local PolyType = {
	subject = 0, clip = 1
}

local PolyFillType = {
	evenOdd = 1, nonZero = 2, positive = 2, negative = 3
}

local Path = {}

function Path.New()
	return ffi.gc(C.cl_path_new(), C.cl_path_free)
end

function Path:Add(x,y)
  return C.cl_path_add(self,x,y)
end

function Path:Get(i)
  return C.cl_path_get(self,i-1)
end

function Path:Size()
	return C.cl_path_size(self)
end

function Path:Area()
	return C.cl_path_area(self)
end

function Path:Reverse()
	return C.cl_path_reverse(self)
end

function Path:Orientation()
	return C.cl_path_orientation(self)
end

function Path:IsPointInPolygon(x,y)
	return C.cl_path_point_in_polygon(self,x,y)
end

function Path:Simplify(fillType)
	fillType = fillType or 'evenOdd'
	fillType = assert(PolyFillType[fillType],'unknown fill type')
	return C.cl_path_simplify(self,fillType)
end

function Path:CleanPolygon(distance)
	distance = distance or 1.415
	return C.cl_path_clean_polygon(self,distance)
end

local Paths = {}

function Paths.New()
	return ffi.gc(C.cl_paths_new(), C.cl_paths_free)
end

function Paths:Add(path)
  return C.cl_paths_add(self,path)
end

function Paths:Get(i)
  return C.cl_paths_get(self,i-1)
end

function Paths:Size()
	return C.cl_paths_size(self)
end

local ClipperOffset = {}

function ClipperOffset.New(miterLimit,roundPrecision)
  local co = C.cl_offset_new(miterLimit or 2,roundPrecision or 0.25)
	return ffi.gc(co, C.cl_offset_free)
end

function ClipperOffset:OffsetPath(path,delta,jt,et)
	jt,et = jt or 'square', et or 'openButt'
	assert(JoinType[jt])
	assert(EndType[et])
	local out = C.cl_offset_path(self,path,delta,JoinType[jt],EndType[et])
	if out == nil then
		error(ffi.string(C.cl_err_msg()))
	end
	return out
end

function ClipperOffset:OffsetPaths(paths,delta,jt,et)
	jt,et = jt or 'square', et or 'openButt'
	assert(JoinType[jt])
	assert(EndType[et])
	local out = C.cl_offset_paths(self,paths,delta,JoinType[jt],EndType[et])
	if out == nil then
		error(ffi.string(C.cl_err_msg()))
	end
	return out
end

function ClipperOffset:Clear()
	C.cl_offset_clear(self)
end

local Clipper = {}

function Clipper.New(...)
  local cl = C.cl_clipper_new()
  for _,opt in ipairs {...} do
		assert(InitOptions[opt])
		if opt == 'strictlySimple' then
			C.cl_clipper_strictly_simple(true)
		elseif opt == 'reverseSolution' then
			C.cl_clipper_reverse_solution(true)
		else
			C.cl_clipper_preserve_collinear(true)
		end
	end
	return ffi.gc(cl, C.cl_clipper_free)
end

function Clipper:Clear()
	C.cl_clipper_clear(self)
end

function Clipper:AddPath(path,pt,closed)
	assert(path,'path is nil')
	assert(PolyType[pt],'unknown polygon type')
	if closed == nil then closed = true end
	C.cl_clipper_add_path(self,path,PolyType[pt],closed,err);
end

function Clipper:AddPaths(paths, pt, closed)
	assert(paths,'paths is nil')
	assert(PolyType[pt],'unknown polygon type')
	if closed == nil then closed = true end
	if not C.cl_clipper_add_paths(self,paths,PolyType[pt],closed,err) then
		error(ffi.string(C.cl_err_msg()))
	end
end

function Clipper:Execute(clipType, subjFillType, clipFillType)
	subjFillType = subjFillType or 'evenOdd'
	clipFillType = clipFillType or 'evenOdd'
	clipType = assert(ClipType[clipType],'unknown clip type')
	subjFillType = assert(PolyFillType[subjFillType],'unknown fill type')
	clipFillType = assert(PolyFillType[clipFillType],'unknown fill type')
	local out = C.cl_clipper_execute(self,clipType,subjFillType,clipFillType)
	-- XXX test `not nil` return false ?!
	if not out then error(ffi.string(C.cl_err_msg())) end
	return out
end

function Clipper:GetBounds()
	local r = C.cl_clipper_get_bounds(self)
	return tonumber(r.left),tonumber(r.top),tonumber(r.right),tonumber(r.bottom)
end

ffi.metatype('cl_path', {__index = Path})
ffi.metatype('cl_paths', {__index = Paths})
ffi.metatype('cl_offset', {__index = ClipperOffset})
ffi.metatype('cl_clipper', {__index = Clipper})

return {
	Path = Path.New,
	Paths = Paths.New,
	ClipperOffset = ClipperOffset.New,
	Clipper = Clipper.New,
}
