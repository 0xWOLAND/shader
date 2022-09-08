struct vertexInput {
    @location(0) position: vec4<f32>;
    @location(1) color: vec4<f32>;
};

struct VertexOut {
    @builtin(position) position : vec4<f32>;
    @location(0) color : vec4<f32>;
};

@stage(vertex)
fn vertex_main(input : vertexInput) -> VertexOut
{
    var output : VertexOut;
    output.position = input.position;
    output.color = input.color;
    return output;
}

struct UniformBG {
    @location(0) time : f32;
    @location(1) resolution : vec2<f32>;
    @location(2) grey: f32;
    @location(3) textureLayer: i32;
};

struct rayInfo {
    rayDirection: vec3<f32>;
    rayPosition: vec3<f32>;
};
struct cameraInfo {
    cameraPosition : vec3<f32>;
    cameraRight: vec3<f32>;
    cameraUp: vec3<f32>;
    cameraForward: vec3<f32>;
    cameraAspectRatio : vec2<f32>;
    cameraPinHoleDistance : f32;
    cameraPinHolePosition : vec3<f32>;
}

struct rayHit {
    hitNormal : vec3<f32>;
    hitPosition : vec3<f32>;
    distance : f32;
    isHit : bool;
}

@group(0) @binding(0)
var <uniform> uniforms : UniformBG;
@group(0) @binding(1)
var octreeTexture : texture_3d<u32>;


var<private> originalRay : rayInfo;
var<private> cameraSettings : cameraInfo;

@stage(fragment)
fn fragment_main(fragData: VertexOut) -> @location(0) vec4<f32>
{
    cameraSettings = generateCameraInfo();
    originalRay = calculateOriginalRay(fragData);
    var val : f32 = rayMarch(originalRay);
    var rayHitInformation : rayHit;
    return vec4<f32>(vec3<f32>((val)), 1.);
}

fn rayMarch(origin : rayInfo) -> f32 {
    var currPos : vec3<f32> = origin.rayPosition;
    var dir : vec3<f32> = origin.rayDirection; 
    var maxIter = 100;
    var iter : i32 = 0;
    for (var i : i32 = 0; i < maxIter; ) {
        var minDist : f32 = DE(currPos);
        currPos = currPos + dir * minDist;
        if (minDist < .001) {
            break;
        }
        i = i + 1;
        iter = iter + 1;
    }
    return 1. - f32(iter) / f32(maxIter);
}

fn DE(z : vec3<f32>) -> f32 {
    return IFS(z);//MB(z)
}

fn fold (z : vec3<f32>, norm: vec3<f32>) -> vec3<f32> {
    return z - 2. * min(0., dot(z, norm)) * norm;
}

fn op(z : vec3<f32>) -> vec3<f32> {
    return (1. - length(z)) * normalize(z) + z;
}

fn trap(z : vec3<f32>) -> f32 {
    //return length(z) - 1.;
    var t = vec2<f32>(1., 1.);
    var q = vec2<f32>(length(z.xz) - t.x, z.y);
    return length(q) - t.y;
}

/*
vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
      if(x+y<0){x1=-y;y=-x;x=x1;}
      if(x+z<0){x1=-z;z=-x;x=x1;}
      if(y+z<0){y1=-z;z=-y;y=y1;}
      
      //Stretche about the point [1,1,1]*(scale-1)/scale; The "(scale-1)/scale" is here in order to keep the size of the fractal constant wrt scale
      x=scale*x-(scale-1);//equivalent to: x=scale*(x-cx); where cx=(scale-1)/scale;
      y=scale*y-(scale-1);
      z=scale*z-(scale-1);
      r=x*x+y*y+z*z;
*/

fn IFS(z : vec3<f32>) -> f32 {
    var pos : vec3<f32> = z;

    var Scale : f32 = 2.;
    var Bailout : f32 = 100.;

    var i : i32 = 0;
    var d : f32 = 1000.;
    for ( ; i < 20; ) {
        if (length(pos) > Bailout) {
            break;
        }
        
        var temp : f32 = 0.;
        if (pos.x + pos.y < 0.) {
            temp = -pos.y;
            pos.y = -pos.x;
            pos.x = temp;
        }
        if (pos.x + pos.z < 0.) {
            temp = -pos.z;
            pos.z = -pos.x;
            pos.x = temp;
        }
        if (pos.y + pos.z < 0.) {
            temp = -pos.z;
            pos.z = -pos.y;
            pos.y = temp;
        }
        //pos = abs(pos);
        
        pos.x = Scale * pos.x - (Scale - 1.);
        pos.y = Scale * pos.y - (Scale - 1.);
        pos.z = Scale * pos.z - (Scale - 1.);
        //pos = Scale * pos - Scale - 1.;
        //pos = normalize(pos) * 10.;
        //pos = fold(pos, normalize(vec3<f32>(1.)));
        //pos = vec3<f32>(rotate2d(pos.xy, 37.), pos.z);
        //pos = vec3<f32>(pos.x, rotate2d(pos.yz, 15.));
        //pos = vec3<f32>(pos.x, rotate2d(pos.yz, 45.));
        //pos = pos + .1 * vec3<f32>(1., 1., 1.);
        //d = min(d, trap(pos) * pow(Scale, f32(-i)));// * pow(Scale, f32(-i)
        i = i + 1;
        d = min(d, length(pos) * pow(Scale, f32(-i)));
    }
    //return (sqrt(r)-2)*scale^(-i);
    //return length(z)*pow(Scale, float(-n));
    //return (length(pos)) * pow(Scale, f32(-i));
    return d;
    //return sqrt(length(pos) - 2.) * pow(Scale, f32(-i));
}

fn MB(pos : vec3<f32>) -> f32 {
    var z : vec3<f32> = pos;
    var dr : f32 = 1.;
    var r : f32 = 0.;

    var mbIterations : i32 = 5;

    var Power : f32 = 6.;

    for (var i : i32 = 0; i < mbIterations; ) {
        r = length(z);
        if (r > 100.) {
            break;
        }
        var theta : f32 = acos(z.z / r);
        var phi : f32 = atan(z.y / z.x);
        dr = pow(r, Power - 1.) * Power * dr + 1.;

        var zr : f32 = pow(r, Power);
        theta = theta * Power;
        phi = phi * Power;

        z = zr * vec3<f32>(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
        z = z + pos;
        i = i + 1;
    }
    return .5 * log(r) * r / dr;
}

fn rotate2d(input : vec2<f32>, theta : f32) -> vec2<f32> {
    var c : f32 = cos(theta);
    var s : f32 = sin(theta);
    var rotationMatrix : mat2x2<f32> = mat2x2<f32>(c, -s, s, c);
    return rotationMatrix * input;
}

fn generateCameraInfo() -> cameraInfo {
    var cam : cameraInfo;
    var zRotation : f32 = -3.14157 / 4.;
    var rotationResult : vec2<f32>;
    cam.cameraPosition = vec3<f32>(0., -1. * 10., 0.);
    cam.cameraRight = vec3<f32>(1., 0., 0.);
    cam.cameraUp = vec3<f32>(0., 0., 1.);
    rotationResult = rotate2d(cam.cameraPosition.zy, zRotation);
    cam.cameraPosition = vec3<f32>(cam.cameraPosition.x, rotationResult.y, rotationResult.x);
    cam.cameraPosition = vec3<f32>(rotate2d(cam.cameraPosition.xy, uniforms.grey * 2.), cam.cameraPosition.z);
    cam.cameraRight = vec3<f32>(rotate2d(cam.cameraRight.xy, uniforms.grey * 2.), cam.cameraRight.z);
    cam.cameraForward = normalize( -cam.cameraPosition );
    rotationResult = rotate2d(cam.cameraUp.zy, zRotation);
    cam.cameraUp = vec3<f32>(cam.cameraUp.x, rotationResult.y, rotationResult.x);
    cam.cameraUp = vec3<f32>(rotate2d(cam.cameraUp.xy, uniforms.grey * 2.), cam.cameraUp.z);
    cam.cameraAspectRatio = vec2<f32>(1., uniforms.resolution.y / uniforms.resolution.x);
    cam.cameraPinHoleDistance = 1.;
    cam.cameraPinHolePosition = cam.cameraPosition + cam.cameraForward * -1. * cam.cameraPinHoleDistance;
    return cam;
}

fn calculateOriginalRay(fragData: VertexOut) -> rayInfo {
    var relPos : vec2<f32> = fragData.position.xy / uniforms.resolution - vec2<f32>(.5);
    relPos = relPos * vec2<f32>(1., -1.);
    var returnedRay : rayInfo;
    returnedRay.rayPosition = relPos.x * cameraSettings.cameraRight * cameraSettings.cameraAspectRatio.x + relPos.y * cameraSettings.cameraUp * cameraSettings.cameraAspectRatio.y + cameraSettings.cameraPosition;
    returnedRay.rayDirection = normalize(returnedRay.rayPosition - cameraSettings.cameraPinHolePosition);
    return returnedRay;
}

