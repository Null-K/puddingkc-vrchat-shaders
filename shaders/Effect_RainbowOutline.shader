Shader "PuddingKC/Effects/RainbowOutline"
{
    Properties
    {
        _OutlineWidth ("Outline Width", Range(0.0, 0.05)) = 0.01
        _ColorSpeed ("Color Change Speed", Range(0.0, 10.0)) = 1.5
        _OutlineIntensity ("Outline Intensity", Range(0.0, 3.0)) = 1.2
        _OutlineAlpha ("Outline Alpha", Range(0.0, 1.0)) = 1.0
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }

        Pass
        {
            Name "OUTLINE"
            Cull Front
            ZWrite Off
            ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float _OutlineWidth, _ColorSpeed, _OutlineIntensity, _OutlineAlpha;

            struct appdata
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 rainbow : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float3 HueShift(float h)
            {
                float3 rgb = saturate(abs(frac(h + float3(0.0, 0.6666667, 0.3333333)) * 6.0 - 3.0) - 1.0);
                return rgb * rgb * (3.0 - 2.0 * rgb);
            }

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                worldPos += normalize(worldNormal) * _OutlineWidth;

                o.vertex = UnityWorldToClipPos(float4(worldPos, 1.0));

                float hue = frac(_Time.y * _ColorSpeed);
                o.rainbow = HueShift(hue) * _OutlineIntensity;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                return fixed4(i.rainbow, _OutlineAlpha);
            }
            ENDCG
        }
    }

    Fallback Off
}
