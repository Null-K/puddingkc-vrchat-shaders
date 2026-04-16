Shader "PuddingKC/Effects/Blur"
{
    Properties
    {
        _BlurSize ("Blur Size", Range(0.001, 0.05)) = 0.014
        _BlurStrength ("Blur Strength", Range(0,1)) = 1
        _EdgeSoftness ("Edge Softness", Range(0.01, 0.8)) = 0.22
        _Chromatic ("Chromatic Aberration", Range(0, 0.02)) = 0.0005
        _Distortion ("Distortion", Range(0,0.01)) = 0
        _MosaicSize ("Mosaic Size", Range(8,160)) = 52
        _CenterSoftness ("Center Density", Range(0.5, 3.0)) = 1.6
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
        GrabPass { "_GrabTexture" }

        Pass
        {
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _GrabTexture;
            float4 _GrabTexture_TexelSize;
            float _BlurSize, _BlurStrength, _EdgeSoftness, _Distortion, _Chromatic, _MosaicSize, _CenterSoftness;

            struct appdata { UNITY_VERTEX_INPUT_INSTANCE_ID float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float4 vertex : SV_POSITION; float4 screenPos : TEXCOORD0; float2 uv : TEXCOORD1; UNITY_VERTEX_OUTPUT_STEREO };

            v2f vert(appdata v) {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float2 uv = i.screenPos.xy / i.screenPos.w;

                if (_Distortion > 0.0)
                {
                    float t = _Time.y * 2.0;
                    uv += float2(sin(uv.y * 18.0 + t), cos(uv.x * 18.0 + t)) * _Distortion;
                }

                float2 boxUV = abs(i.uv - 0.5) * 2.0;
                float edgeDist = max(boxUV.x, boxUV.y);
                float boxMask = 1.0 - smoothstep(1.0 - _EdgeSoftness, 1.0, edgeDist);
                float finalMask = saturate(pow(boxMask, _CenterSoftness)) * _BlurStrength;

                float mosaicScale = max(_MosaicSize, 1.0);
                float2 mosaicUV = floor(uv * mosaicScale) / mosaicScale;
                fixed4 mosaicCol = tex2D(_GrabTexture, mosaicUV);

                fixed4 blurCol = 0;
                const int SAMPLE_COUNT = 20;

                for (int j = 0; j < SAMPLE_COUNT; j++) {
                    float angle = 6.2831853 * j / SAMPLE_COUNT;
                    float2 dir = float2(cos(angle), sin(angle));
                    float ring = (j % 2 == 0) ? 1.0 : 0.55;
                    float2 offset = dir * _BlurSize * ring;

                    blurCol.r += tex2D(_GrabTexture, uv + offset - dir * _Chromatic).r;
                    blurCol.g += tex2D(_GrabTexture, uv + offset).g;
                    blurCol.b += tex2D(_GrabTexture, uv + offset + dir * _Chromatic).b;
                }

                blurCol /= SAMPLE_COUNT;
                blurCol.a = 1.0;

                fixed4 censoredCol = lerp(mosaicCol, blurCol, 0.72);
                fixed4 original = tex2D(_GrabTexture, uv);

                return lerp(original, censoredCol, finalMask);
            }
            ENDCG
        }
    }
    Fallback "Transparent/VertexLit"
}
