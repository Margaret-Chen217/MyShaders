Shader "3300/Grass"
{
    Properties
    {
        [Header(Shading)]
        _TopColor("Top Color", Color) = (1,1,1,1)
        _BottomColor("Bottom Color", Color) = (1,1,1,1)
        _TranslucentGain("Translucent Gain", Range(0,1)) = 0.5

        [Header(Blade)]
        _BendRotationRandom("Bend Rotation Random", Range(0,1)) = 0.2
        _BladeWidth("Blade Width", range(0.0,1.0)) = 0.05
        _BladeWidthRandom("Blade Width Random", range(0.0,1.0)) = 0.02
        _BladeHeight("Blade Height", range(0.0,1.0)) = 0.5
        _BladeHeightRandom("Blade Height Random",range(0.0,1.0)) = 0.3
        _BladeForward("Blade Forward Amount", range(0,1)) = 0.38
        _BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2

        [Header(Tessellation)]
        _TessellationUniform("TessellationUniform",Range(1,64)) = 1

        [Header(Wind)]
        _WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
        _WindStrength("Wind Strength", float) = 1

        [Header(Interactive)]
        _InteractiveRadius("Radius", float) = 4
        _InteractiveStrength("Strength", float) = 2
        _LengthOffset("LengthOffset", vector) = (0.3,0.3,0.0,0.0)

        //        [Header(Debug)]
        //        _PositionMoving("PositionMoving", vector) = (0.0,0.0,0.0)
        [HideInInspector]_Test("Test", range(0.0,1.0)) = 0.5
    }

    CGINCLUDE
    #include "UnityCG.cginc"
    #include "Autolight.cginc"
    #include "CustomTessellation.cginc"
    #define BLADE_SEGMENTS 5

    float _BendRotationRandom;
    float _BladeForward;
    float _BladeCurve;
    float _BladeHeight;
    float _BladeHeightRandom;
    float _BladeWidth;
    float _BladeWidthRandom;
    uniform float3 _PositionMoving;

    sampler2D _WindDistortionMap;
    float4 _WindDistortionMap_ST;
    float2 _WindFrequency;
    float _WindStrength;

    float _InteractiveRadius;
    float _InteractiveStrength;
    float3 _LengthOffset;

    float _Test;

    // Simple noise function, sourced from http://answers.unity.com/answers/624136/view.html
    // Extended discussion on this function can be found at the following link:
    // https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
    // Returns a number in the 0...1 range.
    //生成一个0~1的随机数
    float rand(float3 co)
    {
        return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
    }

    // Construct a rotation matrix that rotates around the provided axis, sourced from:
    // https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
    //接受弧度制角度，返回7围绕提供轴旋转的矩阵
    float3x3 AngleAxis3x3(float angle, float3 axis)
    {
        float c, s;
        sincos(angle, s, c);

        float t = 1 - c;
        float x = axis.x;
        float y = axis.y;
        float z = axis.z;

        return float3x3(
            t * x * x + c, t * x * y - s * z, t * x * z + s * y,
            t * x * y + s * z, t * y * y + c, t * y * z - s * x,
            t * x * z - s * y, t * y * z + s * x, t * z * z + c
        );
    }


    struct geometryOutput
    {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0; //为生成的草添加uv
        float3 normal :NORMAL;
        unityShadowCoord4 _ShadowCoord : TEXCOORD1;
    };

    //生成叶片数据
    geometryOutput VertexOutput(float3 pos, float2 uv, float3 normal)
    {
        //将
        geometryOutput o;
        o.pos = UnityObjectToClipPos(pos);
        o.uv = uv;
        o._ShadowCoord = ComputeScreenPos(o.pos);
        o.normal = UnityObjectToWorldNormal(normal);
        #if UNITY_PASS_SHADOWCASTER
	    // Applying the bias prevents artifacts from appearing on the surface.
	    o.pos = UnityApplyLinearShadowBias(o.pos);
        #endif
        return o;
    }


    //增加草叶顶点
    geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 uv
                                       , float3x3 transformMatrix)
    {
        float3 tangentPoint = float3(width, forward, height);
        float3 tangentNormal = float3(0, -1, forward);
        float3 localNormal = mul(transformMatrix, tangentNormal);
        float3 localPosition = vertexPosition + mul(transformMatrix, tangentPoint);
        return VertexOutput(localPosition, uv, localNormal);
    }

    [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
    void geom(triangle vertexOutput IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
    {
        //pos是输入的三角形片元的第1个顶点
        float3 pos = IN[0].vertex;

        //TBN
        float3 vNormal = IN[0].normal;
        float4 vTangent = IN[0].tangent;
        float3 vBinormal = cross(vNormal, vTangent) * vTangent.w;
        //世界空间顶点位置
        float4 worldPos = mul(unity_ObjectToWorld, pos);

        //构建TBN矩阵
        float3x3 tangentToLocal = float3x3(
            vTangent.x, vBinormal.x, vNormal.x,
            vTangent.y, vBinormal.y, vNormal.y,
            vTangent.z, vBinormal.z, vNormal.z);

        //随机朝向
        float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));
        //随机弯曲
        float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5,
                                                   float3(-1, 0, 0));

        //构建uv
        float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;

        //wind
        //采样风噪声贴图
        float2 windSample = tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * _WindStrength;
        float3 wind = normalize(float3(windSample.x, windSample.y, 0));

        //wind旋转矩阵
        float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);

        //随机朝向 + 随机弯曲 + 风
        float3x3 transformationMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix),
                                            bendRotationMatrix);
        //三角形底部两点不要 随机弯曲 和 风
        float3x3 transformationMatrixFacing = mul(tangentToLocal, facingRotationMatrix);

        //float3x3 transformationMatrix = mul(mul(tangentToLocal, facingRotationMatrix), bendRotationMatrix);

        //随机大小
        float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
        float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;

        //弯曲
        float forward = rand(pos.yyz) * _BladeForward;

        //interactive
        float3 dis = distance(_PositionMoving, worldPos); //distance for radius
        float3 radius = 1 - saturate(dis / _InteractiveRadius);
        float3 sphereDisp = worldPos - _PositionMoving;
        sphereDisp *= radius;

        sphereDisp = clamp(sphereDisp.xyz * _InteractiveStrength, -0.5, 0.5);

        float t;
        //增加顶点
        for (int i = 0; i < BLADE_SEGMENTS; i++)
        {
            //计算高度、宽度偏移
            t = i / (float)BLADE_SEGMENTS;
            float segmentHeight = height * t;
            float segmentWidth = width * (1 - t);
            float segmentForward = pow(t, _BladeCurve) * forward;


            //将顶点添加到三角形流中
            //判断是不是底部顶点，底部顶点不旋转
            float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

            //float3 interactivePos = clamp((pos + sphereDisp * t), _LengthOffset.x, _LengthOffset.y);
            //float3 newPos = i == 0 ? pos : (pos + (sphereDisp.xyz + wind) * t);
            float3 newPos = i == 0
                                ? pos
                                : (pos + float3(sphereDisp.x * _LengthOffset.x, sphereDisp.y * _LengthOffset.y,
                                                sphereDisp.z * _LengthOffset.z) * t);
            //float3 newPos = i == 0 ? pos : sphereDisp;

            //newPos = lerp(pos, newPos, _Test);

            triStream.Append(GenerateGrassVertex(newPos, segmentWidth, segmentHeight, segmentForward, float2(0, t),
                                                 transformMatrix));
            triStream.Append(GenerateGrassVertex(newPos, -segmentWidth, segmentHeight, segmentForward, float2(1, t),
                                                 transformMatrix));
        }
        //顶部顶点
        float3 newPos = pos + float3(sphereDisp.x * _LengthOffset.x, sphereDisp.y * _LengthOffset.y,
                                                sphereDisp.z * _LengthOffset.z) ;
        //float3 newPos = i == 0 ? pos : sphereDisp;

        //newPos = lerp(pos, newPos, _Test);

        triStream.Append(GenerateGrassVertex(newPos, 0, height, forward, float2(0.5, 1), transformationMatrix));
        triStream.RestartStrip();
    }
    ENDCG

    SubShader
    {
        Cull Off

        Pass
        {
            Tags
            {
                "RenderType" = "Opaque"
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM
            #pragma hull hull
            #pragma domain domain
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma target 4.6

            #include "Lighting.cginc"

            float4 _TopColor;
            float4 _BottomColor;
            float _TranslucentGain;
            // float  _BendRotationRandom;


            float4 frag(geometryOutput i, fixed facing : VFACE) : SV_Target
            {
                //双面渲染翻转法线
                float3 normal = facing > 0 ? i.normal : -i.normal;
                float shadow = SHADOW_ATTENUATION(i);
                float ndl = saturate(saturate(dot(normal, _WorldSpaceLightPos0.xyz)) + _TranslucentGain) * shadow;

                float3 ambient = ShadeSH9(float4(normal, 1));
                float4 lightIntensity = ndl * _LightColor0 + float4(ambient, 1);
                float4 col = lerp(_BottomColor, _TopColor, i.uv.y);
                //float4 col = lerp(_BottomColor, _TopColor, i.uv.y) * lightIntensity;
                return col;
            }
            ENDCG
        }
        Pass
        {
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            CGPROGRAM
            #pragma hull hull
            #pragma domain domain
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma target 4.6
            #pragma multi_compile_shadowcaster

            float4 frag(geometryOutput i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
}