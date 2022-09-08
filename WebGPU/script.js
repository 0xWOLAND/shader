
var shaderCode = ``;
var datInput = {
    color: [200, 200, 200],
    grey: 50,
    textureLayer: 0
};
var gui;
const uniformBytes = 24;
(async () => {
    console.log("Hello");
    if (!navigator.gpu) {
        alert("WebGPU is not supported");
        return;
    }
    var adapter = await navigator.gpu.requestAdapter({
        powerPreference: "high-performance"
    });
    var device = await adapter.requestDevice();

    shaderCode = await fetch('shader.wgsl').then(result => result.text());
    
    gui = initializeGUI();

    const canvas = document.querySelector("#targetCanvas");
    canvas.width = canvas.clientWidth;
    canvas.height = canvas.clientHeight;
    var context = canvas.getContext("webgpu");
    
    context.configure({
        device, format: 'bgra8unorm'
    });

    const shaderModule = device.createShaderModule({
        code: shaderCode
    });

    const vertices = new Float32Array([
        -1.0, -1.0, 0, 1, 0, 0, 1,
        1.0, -1.0, 0, 0, 1, 0, 1,
        1.0, 1.0, 0, 0, 1, 1, 1,
        -1.0, -1.0, 0, 1, 0, 0, 1,
        -1.0, 1.0, 0, 0, 1, 0, 1,
        1.0, 1.0, 0, 0, 1, 1, 1
    ]);

    const vertexBuffer = device.createBuffer({
        size: vertices.byteLength,
        usage: GPUBufferUsage.VERTEX || GPUBufferUsage.COPY_DST,
        mappedAtCreation: true
    });
    new Float32Array(vertexBuffer.getMappedRange()).set(vertices);
    vertexBuffer.unmap();

    var vertexState = {
        module: shaderModule,
        entryPoint: "vertex_main",
        buffers: [{
            attributes: [
                {
                    shaderLocation: 0,
                    offset: 0,
                    format: "float32x3"
                },
                {
                    shaderLocation: 1,
                    offset: 12,
                    format: "float32x4"
                }
            ],
            arrayStride: 28,
            stepMode: "vertex"
        }]
    };

    var fragmentState = {
        module: shaderModule,
        entryPoint: "fragment_main",
        targets: [
            {
                format: "bgra8unorm"
            }
        ]
    };
    
    var bindGroupLayout = device.createBindGroupLayout({
        entries: [
            {
                binding: 0,
                visibility: GPUShaderStage.FRAGMENT,
                buffer: {
                    type: "uniform"
                }
            },
            {
                binding: 1,
                visibility: GPUShaderStage.FRAGMENT,
                texture: {
                    sampleType: "uint",
                    viewDimension: "3d"
                }
            }
        ]
    });

    var layout = device.createPipelineLayout({
        bindGroupLayouts: [bindGroupLayout]
    });

    var renderPipeline = device.createRenderPipeline({
        layout: layout,
        vertex: vertexState,
        fragment: fragmentState
    });

    var renderPassDescriptor = {
        colorAttachments: [
            {
                view: undefined,
                loadOp: "clear",
                clearValue: [.1, .2, .3, 1.],
                storeOp: "store"
            }
        ]
    };

    var uniformBuffer = device.createBuffer({
        size: uniformBytes,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });
    
    const cubeTexture = device.createTexture({
        size: [2, 2, 2],
        format: 'rgba8uint',
        usage: 
            GPUTextureUsage.TEXTURE_BINDING |
            GPUTextureUsage.COPY_DST,
        dimension: '3d'
    });
    
    let array = new Uint8ClampedArray([
        255, 0, 0, 255,
        0, 255, 0, 255,
        0, 0, 255, 255,
        255, 255, 255, 255,
        255, 0, 0, 255,
        0, 255, 0, 255,
        0, 0, 255, 255,
        255, 0, 255, 255
    ]);

    device.queue.writeTexture(
        {
            texture: cubeTexture 
        }, 
        array, 
        { 
            offset: 0,
            bytesPerRow: 8,
            rowsPerImage: 2
        }, 
        {
            width: 2, 
            height: 2,
            depthOrArrayLayers: 2
        }
    );
    
    var uniformBG = device.createBindGroup({
        layout: bindGroupLayout,
        entries: [
            {
                binding: 0,
                resource: {
                    buffer: uniformBuffer
                }
            },
            {
                binding: 1,
                resource: cubeTexture.createView({
                    format: "rgba8uint"
                })
            }
        ]
    });

    var then = 0.;
    var time = 0.;

    var render = function(now) {
        now *= .001;
        const deltaTime = now - then;
        then = now;
        time += deltaTime;
        renderPassDescriptor.colorAttachments[0].view = context.getCurrentTexture().createView();

        var upload = device.createBuffer({
            size: uniformBytes,
            usage: GPUBufferUsage.COPY_SRC, 
            mappedAtCreation: true
        });

        {
            var arrayBuffer = upload.getMappedRange();
            var dataView = new DataView(arrayBuffer);
            dataView.setFloat32(0, time, true);
            dataView.setFloat32(4, 0., true);
            dataView.setFloat32(8, context.canvas.width, true);
            dataView.setFloat32(12, context.canvas.height, true);
            dataView.setFloat32(16, datInput.grey / 100., true);
            dataView.setUint32(20, datInput.textureLayer, true);
            upload.unmap();
        }

        var commandEncoder = device.createCommandEncoder();
        commandEncoder.copyBufferToBuffer(upload, 0, uniformBuffer, 0, uniformBytes);

        var renderPass = commandEncoder.beginRenderPass(renderPassDescriptor);

        renderPass.setPipeline(renderPipeline);
        renderPass.setBindGroup(0, uniformBG);
        renderPass.setVertexBuffer(0, vertexBuffer);
        renderPass.draw(6);

        renderPass.end();
        device.queue.submit([commandEncoder.finish()]);

        requestAnimationFrame(render);
    }
    requestAnimationFrame(render);
})();

function initializeGUI() {
    var g = new dat.GUI({name: "Controls"});
    var inputFolder = g.addFolder("Input");
    inputFolder.add(datInput, "grey", 0, 100);
    inputFolder.add(datInput, "textureLayer", 0, 1000);
}
