local sin, cos, tan, PI, sqrt, max = math.sin, math.cos, math.tan, math.pi, math.sqrt, math.max
local insert, unpack, sort = table.insert, table.unpack, table.sort
local GL_DrawLine, GL_DrawTriangle, GL_DrawRect = Graphics.CSurface.GL_DrawLine, Graphics.CSurface.GL_DrawTriangle, Graphics.CSurface.GL_DrawRect
local Point, FPS = Hyperspace.Point, Hyperspace.FPS

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720


-- Vector3d
local Vector3d = {}

Vector3d.x = 0
Vector3d.y = 0
Vector3d.z = 0
Vector3d.w = 1

Vector3d.new = function(self, x, y, z, w)
  local o = {x = x or 0, y = y or 0, z = z or 0, w = w or 1}
  self.__index = self
  return setmetatable(o, self)
end

Vector3d.__add = function(self, vector)
  return Vector3d:new(self.x + vector.x, self.y + vector.y, self.z + vector.z)
end
Vector3d.__sub = function(self, vector)
  return Vector3d:new(self.x - vector.x, self.y - vector.y, self.z - vector.z)
end
Vector3d.__mul = function(self, number)
  return Vector3d:new(self.x * number, self.y * number, self.z * number)
end
Vector3d.__div = function(self, number)
  return Vector3d:new(self.x / number, self.y / number, self.z / number)
end

Vector3d.GetDotProduct = function(vector1, vector2)
  return vector1.x * vector2.x + vector1.y * vector2.y + vector1.z * vector2.z   
end

Vector3d.GetCrossProduct = function(vector1, vector2)
  return Vector3d:new(
    vector1.y * vector2.z - vector1.z * vector2.y,
    vector1.z * vector2.x - vector1.x * vector2.z,
    vector1.x * vector2.y - vector1.y * vector2.x
  )
end

Vector3d.GetLength = function(self)
  return sqrt(self.GetDotProduct(self, self))
end

Vector3d.Normalize = function(self)
  local length = self:GetLength()
  self.x = self.x / length
  self.y = self.y / length
  self.z = self.z / length
  return self
end

Vector3d.IntersectPlane = function(planeP, planeN, lineStart, lineEnd)
  planeN = Vector3d:new(planeN.x, planeN.y, planeN.z):Normalize()
  local planeD = -Vector3d.GetDotProduct(planeN, planeP)
  local ad = Vector3d.GetDotProduct(lineStart, planeN)
  local bd = Vector3d.GetDotProduct(lineEnd, planeN)
  local t = (-planeD - ad) / (bd - ad)
  local lineStartToEnd = lineEnd - lineStart
  local lineToIntersect = lineStartToEnd * t
  return lineStart + lineToIntersect
end



-- Triangle
local Triangle = {}

Triangle.points = {}
Triangle.color = {0, 0, 0}

Triangle.new = function(self, vec1, vec2, vec3)
  local o = {points = {vec1, vec2, vec3}}

  for _, vec in ipairs(o.points) do
    if getmetatable(vec) ~= Vector3d then
      return log("Error: Triangle.new: vec is not a Vector3d")
    end
  end

  self.__index = self
  return setmetatable(o, self)
end

Triangle.ClipAgainstPlane = function(planeP, planeN, inTri, outTri1, outTri2)
  -- Make sure plane normal is indeed normal
  planeN = Vector3d:new(planeN.x, planeN.y, planeN.z):Normalize()

  -- get the signed distance from point to plane
  local dist = function(p)
    local n = Vector3d:new(p.x, p.y, p.z):Normalize()
    return (planeN.x * p.x + planeN.y * p.y + planeN.z * p.z - Vector3d.GetDotProduct(planeN, planeP))
  end

  -- Create two temporary storage arrays to classify points either side of plane
  -- If distance sign is positive, point lies on "inside" of plane
  local insidePoints = {}
  local outsidePoints = {}
  local insidePointsCount = 0
  local outsidePointsCount = 0

  -- Get signed distance of each point in triangle to plane
  local dist1 = dist(inTri.points[1])
  local dist2 = dist(inTri.points[2])
  local dist3 = dist(inTri.points[3])

  if dist1 >= 0 then
    insidePoints[insidePointsCount + 1] = inTri.points[1]
    insidePointsCount = insidePointsCount + 1
  else
    outsidePoints[outsidePointsCount + 1] = inTri.points[1]
    outsidePointsCount = outsidePointsCount + 1
  end

  if dist2 >= 0 then
    insidePoints[insidePointsCount + 1] = inTri.points[2]
    insidePointsCount = insidePointsCount + 1
  else
    outsidePoints[outsidePointsCount + 1] = inTri.points[2]
    outsidePointsCount = outsidePointsCount + 1
  end

  if dist3 >= 0 then
    insidePoints[insidePointsCount + 1] = inTri.points[3]
    insidePointsCount = insidePointsCount + 1
  else
    outsidePoints[outsidePointsCount + 1] = inTri.points[3]
    outsidePointsCount = outsidePointsCount + 1
  end

  -- classify the triangle points, break the input triangle into smaller output triangles if required
  if insidePointsCount == 0 then
    -- All points lie on the outside of plane
    return 0
  end

  if insidePointsCount == 3 then
    -- All points lie on the inside of plane
    outTri1 = inTri
    return 1
  end

  if insidePointsCount == 1 and outsidePointsCount == 2 then
    -- Triangle should be clipped. As two points lie outside the plane
    -- the triangle simply becomes a smaller triangle

    -- Copy appearance info to new triangle
    outTri1.color = inTri.color

    -- keep inside point
    outTri1.points[1] = insidePoints[1]

    -- the two new points are at the location where the original
    -- sides of the triangle (lines) intersect with the plane
    outTri1.points[2] = Vector3d.IntersectPlane(planeP, planeN, insidePoints[1], outsidePoints[1])
    outTri1.points[3] = Vector3d.IntersectPlane(planeP, planeN, insidePoints[1], outsidePoints[2])
    
    return 1
  end

  if insidePointsCount == 2 and outsidePointsCount == 1 then
    -- Triangle should be clipped. As two points lie inside the plane
    -- the triangle simply becomes a "quad"

    -- Copy appearance info to new triangles
    outTri1.color = inTri.color
    outTri2.color = inTri.color

    -- the first triangle consists of inside points and a new point 
    -- determined by the location where one side of the triangle intersects with the plane
    outTri1.points[1] = insidePoints[1]
    outTri1.points[2] = insidePoints[2]
    outTri1.points[3] = Vector3d.IntersectPlane(planeP, planeN, insidePoints[1], outsidePoints[1])

    -- the second triangle is composed of one of he inside points, a new point
    -- determined by the intersection of the other side of the triangle and the plane,
    -- and the newly created point above
    outTri2.points[1] = insidePoints[2]
    outTri2.points[2] = outTri1.points[3]
    outTri2.points[3] = Vector3d.IntersectPlane(planeP, planeN, insidePoints[2], outsidePoints[1])

    return 2
  end
end



-- Mesh
local Mesh = {}

Mesh.triangles = {}

Mesh.new = function(self, ...)
  local o = {triangles = {...}}

  for _, tri in ipairs(o.triangles) do
    if getmetatable(tri) ~= Triangle then
      return log("Error: Mesh.new: tri is not a Triangle")
    end
  end

  self.__index = self
  return setmetatable(o, self)
end

Mesh.LoadFromFile = function(self, fileName)
  local file = io.open(fileName, "r")
  if not file then 
    log("Error: Mesh.LoadFromFile: file not found")
    return false 
  end

  -- cache of vertices
  local vertices = {}

  local o = {triangles = {}}

  for line in file:lines() do

    if line:sub(1, 1) == "v" then
      local verts = {}
      for vert in string.gmatch(line, "%S+") do
        insert(verts, tonumber(vert) or 'v')
      end

      local vector = Vector3d:new(verts[2], verts[3], verts[4])
      insert(vertices, vector)
    end

    if line:sub(1, 1) == "f" then
      local points = {}
      for point in string.gmatch(line, "%S+") do
        if string.find(point, '/') then
          insert(points, tonumber(string.gmatch(point, "%d+")()))
        else
          insert(points, tonumber(point) or 'f')
        end
      end

      local triangle = Triangle:new(vertices[points[2]], vertices[points[3]], vertices[points[4]])
      insert(o.triangles, triangle)
    end
  end

  file:close()
  self.__index = self
  return setmetatable(o, self)
end



-- Matrix_4x4
local Matrix_4x4 = {}

Matrix_4x4.matrix = {}

Matrix_4x4.new = function(self, ...)
  local temp = {...}
  local o = { matrix = {
    {temp[1], temp[2], temp[3], temp[4]}, 
    {temp[5], temp[6], temp[7], temp[8]}, 
    {temp[9], temp[10], temp[11], temp[12]}, 
    {temp[13], temp[14], temp[15], temp[16]}
  } }
  self.__index = self
  return setmetatable(o, self)
end

Matrix_4x4.__mul = function(self, matOrVec)
  if matOrVec.x and matOrVec.y and matOrVec.z then
    local vec = matOrVec
    return Vector3d:new(
      vec.x * self.matrix[1][1] + vec.y * self.matrix[2][1] + vec.z * self.matrix[3][1] + vec.w * self.matrix[4][1],
      vec.x * self.matrix[1][2] + vec.y * self.matrix[2][2] + vec.z * self.matrix[3][2] + vec.w * self.matrix[4][2],
      vec.x * self.matrix[1][3] + vec.y * self.matrix[2][3] + vec.z * self.matrix[3][3] + vec.w * self.matrix[4][3],
      vec.x * self.matrix[1][4] + vec.y * self.matrix[2][4] + vec.z * self.matrix[3][4] + vec.w * self.matrix[4][4]
    )
  end

  local mat = matOrVec
  local tempMat = self.CreateIdentity()
  for i=1, 4 do
    for j=1, 4 do
      tempMat.matrix[j][i] = self.matrix[j][1] * mat.matrix[1][i] + 
                             self.matrix[j][2] * mat.matrix[2][i] + 
                             self.matrix[j][3] * mat.matrix[3][i] + 
                             self.matrix[j][4] * mat.matrix[4][i];
    end
  end
  return tempMat
end

Matrix_4x4.CreateIdentity = function()
  return Matrix_4x4:new(
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
  )
end

Matrix_4x4.CreateRotationX = function(theta)
  return Matrix_4x4:new(
    1,    0,              0,            0,
    0,    cos(theta/2),   sin(theta/2), 0,
    0,    -sin(theta/2),  cos(theta/2), 0,
    0,    0,              0,            1
  )
end

Matrix_4x4.CreateRotationY = function(theta)
  return Matrix_4x4:new(
    cos(theta/2),   0,    sin(theta/2),   0,
    0,              1,    0,              0,
    -sin(theta/2),  0,    cos(theta/2),   0,
    0,              0,    0,              1
  )
end

Matrix_4x4.CreateRotationZ = function(theta)
  return Matrix_4x4:new(
    cos(theta),   sin(theta),   0,    0,
    -sin(theta),  cos(theta),   0,    0,
    0,            0,            1,    0,
    0,            0,            0,    1
  )
end

Matrix_4x4.CreateTranslation = function(x, y, z)
  return Matrix_4x4:new(
    1,  0,  0,  0,
    0,  1,  0,  0,
    0,  0,  1,  0,
    x,  y,  z,  1
  )
end

Matrix_4x4.CreateProjection = function(fov, ar, nearPlane, farPlane)
  local fovRad = 1 / tan(fov * 0.5 / 180 * PI)
  return Matrix_4x4:new(
    ar * fovRad,      0.0,      0.0,                                                  0.0,
    0.0,              fovRad,   0.0,                                                  0.0,
    0.0,              0.0,      farPlane / (farPlane - nearPlane),                    1.0,
    0.0,              0.0,      (-farPlane * nearPlane) / (farPlane - nearPlane),     0.0
  )
end

Matrix_4x4.PointAt = function(pos, target, up)
  -- calculate new forward direction
  local vNewForward = (target - pos):Normalize()

  -- calculate new up direction
  local a = vNewForward * Vector3d.GetDotProduct(up, vNewForward)
  local vNewUp = (up - a):Normalize()

  -- calculate new right direction
  local vNewRight = Vector3d.GetCrossProduct(vNewUp, vNewForward)

  -- construct Dimensioning and Translation matrix
  local matrix = Matrix_4x4:new(
    vNewRight.x,      vNewRight.y,     vNewRight.z,     0,
    vNewUp.x,         vNewUp.y,        vNewUp.z,        0,
    vNewForward.x,    vNewForward.y,   vNewForward.z,   0,
    pos.x,            pos.y,           pos.z,           1
  )
  
  return matrix
end

Matrix_4x4.QuickInverse = function(m)
  local matrix = Matrix_4x4:new(
    m.matrix[1][1], m.matrix[2][1], m.matrix[3][1], 0,
    m.matrix[1][2], m.matrix[2][2], m.matrix[3][2], 0,
    m.matrix[1][3], m.matrix[2][3], m.matrix[3][3], 0,
    0,              0,              0,              1
  )
  
  matrix.matrix[4][1] = -( m.matrix[4][1] * matrix.matrix[1][1] + m.matrix[4][2] * matrix.matrix[2][1] + m.matrix[4][3] * matrix.matrix[3][1] )
  matrix.matrix[4][2] = -( m.matrix[4][1] * matrix.matrix[1][2] + m.matrix[4][2] * matrix.matrix[2][2] + m.matrix[4][3] * matrix.matrix[3][2] )
  matrix.matrix[4][3] = -( m.matrix[4][1] * matrix.matrix[1][3] + m.matrix[4][2] * matrix.matrix[2][3] + m.matrix[4][3] * matrix.matrix[3][3] )

  return matrix
end



local function Color(r, g, b, a)
  local rr, gg, bb, aa;
  rr = r / 255
  gg = g / 255
  bb = b / 255
  aa = a
  return Graphics.GL_Color(rr, gg, bb, aa)
end

local function TriangleOutline(point1, point2, point3, r, g, b)
  GL_DrawLine(point1.x, point1.y, point2.x, point2.y, 2, Color(r, g, b, 1))
  GL_DrawLine(point2.x, point2.y, point3.x, point3.y, 2, Color(r, g, b, 1))
  GL_DrawLine(point3.x, point3.y, point1.x, point1.y, 2, Color(r, g, b, 1))
end

local function TriangleFill(point1, point2, point3, r, g, b)
  GL_DrawTriangle(
    Point(SCREEN_WIDTH - point1.x, SCREEN_HEIGHT - point1.y),
    Point(SCREEN_WIDTH - point2.x, SCREEN_HEIGHT - point2.y),
    Point(SCREEN_WIDTH - point3.x, SCREEN_HEIGHT - point3.y),
    Color(r, g, b, 1)
  )
end



local object = Mesh:LoadFromFile('axis.obj')



-- projection matrix
local matMeshProjection = Matrix_4x4.CreateProjection(90, SCREEN_HEIGHT / SCREEN_WIDTH, 0.1, 1000)



local should_draw = false
local elapsed_time = 0

-- script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
--   elapsed_time = elapsed_time + (FPS.SpeedFactor / 16)
-- end)


-- camera vector
local vCamera = Vector3d:new(0, 0, 0)
local vLookDir = Vector3d:new(0, 0, 1)
local yaw = 0

script.on_game_event("STICK1_UP", false, function() -- forward
  vCamera.y = vCamera.y + 1
end)

script.on_game_event("STICK1_DOWN", false, function() -- backward
  vCamera.y = vCamera.y - 1
end)

script.on_game_event("STICK1_LEFT", false, function() -- left
  vCamera.x = vCamera.x + 1
end)

script.on_game_event("STICK1_RIGHT", false, function() -- right
  vCamera.x = vCamera.x - 1
end)


local vForward = vLookDir * 8

script.on_game_event("STICK2_UP", false, function() -- foward
  vCamera = vCamera + vForward
end)

script.on_game_event("STICK2_DOWN", false, function() -- backward
  vCamera = vCamera - vForward
end)

script.on_game_event("STICK2_LEFT", false, function() -- turn left
  yaw = yaw - 1
end)

script.on_game_event("STICK2_RIGHT", false, function() -- turn right
  yaw = yaw + 1
end)

script.on_render_event(Defines.RenderEvents.LAYER_PLAYER, function()end, function()
  if not should_draw then return end

  GL_DrawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, Color(0, 0, 0, 1))

  local theta = 0

  -- rotation matrices
  local matRotationZ = Matrix_4x4.CreateRotationZ(theta * 0.5)
  local matRotationX = Matrix_4x4.CreateRotationX(theta)

  -- translation matrix
  local matTranslation = Matrix_4x4.CreateTranslation(0, 0, 10)

  -- world matrix
  local matWorld = Matrix_4x4.CreateIdentity()
  matWorld = matRotationZ * matRotationX
  matWorld = matWorld * matTranslation


  -- camera movements 
  local vUp = Vector3d:new(0, 1, 0)
  local vTarget = Vector3d:new(0, 0, 1)
  local matCameraRot = Matrix_4x4.CreateRotationY(yaw)
  vLookDir = matCameraRot * vTarget
  vTarget = vCamera + vLookDir

  local matCamera = Matrix_4x4.PointAt(vCamera, vTarget, vUp)

  local matView = Matrix_4x4.QuickInverse(matCamera)


  -- store triangle for rastering later
  local trianglesToDraw = {}


  -- draw triangles
  for i = 1, #object.triangles do
    local triangle = object.triangles[i]
    
    local triangleTransformed = Triangle:new(
      matWorld * triangle.points[1],
      matWorld * triangle.points[2],
      matWorld * triangle.points[3]
    )

    
    -- get lines from triangle
    local line1 = triangleTransformed.points[2] - triangleTransformed.points[1]
    local line2 = triangleTransformed.points[3] - triangleTransformed.points[1]

    
    -- take cross product of lines to get normal to the triangle face
    local normal = Vector3d.GetCrossProduct(line1, line2):Normalize()


    -- get the ray from the camera to the triangle
    local vCameraRay = triangleTransformed.points[1] - vCamera

    -- if ray i aligned with the normal, then the triangle is visible
    if Vector3d.GetDotProduct(normal, vCameraRay) < 0 then

      -- lighting source
      local vLightDirection = Vector3d:new(0, 1, -1):Normalize()


      -- how aligned are the light direction and the triangle normal?
      local dotProduct = max(0.1, Vector3d.GetDotProduct(vLightDirection, normal))


      -- convert world space --> view space
      local triangleViewed = Triangle:new(
        matView * triangleTransformed.points[1],
        matView * triangleTransformed.points[2],
        matView * triangleTransformed.points[3]
      )


      -- project the 3D --> 2D
      local triangleProjected = Triangle:new(
        matMeshProjection * triangleViewed.points[1],
        matMeshProjection * triangleViewed.points[2],
        matMeshProjection * triangleViewed.points[3]
      )


      -- scale into view, manual normalising
      triangleProjected.points[1] = triangleProjected.points[1] / triangleProjected.points[1].w
      triangleProjected.points[2] = triangleProjected.points[2] / triangleProjected.points[2].w
      triangleProjected.points[3] = triangleProjected.points[3] / triangleProjected.points[3].w
      

      -- scale into view
      local vOffsetView = Vector3d:new(1, 1, 0)
      triangleProjected.points[1] = triangleProjected.points[1] + vOffsetView
      triangleProjected.points[2] = triangleProjected.points[2] + vOffsetView
      triangleProjected.points[3] = triangleProjected.points[3] + vOffsetView

      triangleProjected.points[1].x = triangleProjected.points[1].x * (0.5 * SCREEN_WIDTH)
      triangleProjected.points[1].y = triangleProjected.points[1].y * (0.5 * SCREEN_HEIGHT)
      triangleProjected.points[2].x = triangleProjected.points[2].x * (0.5 * SCREEN_WIDTH)
      triangleProjected.points[2].y = triangleProjected.points[2].y * (0.5 * SCREEN_HEIGHT)
      triangleProjected.points[3].x = triangleProjected.points[3].x * (0.5 * SCREEN_WIDTH)
      triangleProjected.points[3].y = triangleProjected.points[3].y * (0.5 * SCREEN_HEIGHT)
      

      -- store the triangle for sorting and drawing
      triangleProjected.color = {dotProduct ^ 2 * 255, dotProduct ^ 2 * 255, dotProduct ^ 2 * 255}
      trianglesToDraw[#trianglesToDraw + 1] = triangleProjected
    end
  end

  -- sort the triangles from back to front
  sort(trianglesToDraw, function(t1, t2)
    local zAvg1 = (t1.points[1].z + t1.points[2].z + t1.points[3].z) / 3
    local zAvg2 = (t2.points[1].z + t2.points[2].z + t2.points[3].z) / 3
    return zAvg1 > zAvg2
  end)

  -- draw triangles in order of distance from the camra, from the queue
  for i = 1, #trianglesToDraw do
    local triangle = trianglesToDraw[i]
    local color = triangle.color
    TriangleFill(triangle.points[1], triangle.points[2], triangle.points[3], color[1], color[2], color[3])
    -- TriangleOutline(triangle.points[1], triangle.points[2], triangle.points[3], 0, 0, 0)
  end
  
end)


script.on_game_event("CANVAS_INIT", false, function()
  should_draw = true
end)

script.on_game_event("CANVAS_END", false, function()
  should_draw = false
end)
