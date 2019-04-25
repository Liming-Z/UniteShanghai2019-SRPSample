using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.LWRP;
using System;

namespace UnityEngine.Rendering.LWRP
{
    public class BlurGrabFeature : ScriptableRendererFeature
    {
        private GrabPassImpl m_GrabPass;
        public BlurGrabSettings settings = new BlurGrabSettings();
        
        const string k_BasicBlitShader = "Hidden/BasicBlit";
        private Material m_BasicBlitMaterial;

        const string k_BlurShader = "Hidden/Blur";
        private Material m_BlurMaterial;

        private Vector2 currentBlurAmount;
        
        [System.Serializable]
        public class BlurGrabSettings
        {
            public Vector2 BlurAmount;
        }
        
        public override void Create()
        {
            m_BasicBlitMaterial = CoreUtils.CreateEngineMaterial(Shader.Find(k_BasicBlitShader));
            m_BlurMaterial = CoreUtils.CreateEngineMaterial(Shader.Find(k_BlurShader));
            currentBlurAmount = settings.BlurAmount;

            m_GrabPass = new GrabPassImpl(m_BlurMaterial, currentBlurAmount, m_BasicBlitMaterial);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var src = renderer.cameraColorTarget;
            var dest = RenderTargetHandle.CameraTarget;


            m_GrabPass.Setup(src, dest.Identifier());

            renderer.EnqueuePass(m_GrabPass);
        }
    }


    public class GrabPassImpl : ScriptableRenderPass
    {
        const string k_RenderGrabPassTag = "Blur Refraction Pass";

        private Material m_BlurMaterial;
        
        private Material m_BlitMaterial;

        private Vector2 m_BlurAmount;

        private RenderTextureDescriptor m_BaseDescriptor;
        private RenderTargetIdentifier source;
        private RenderTargetIdentifier destination { get; set; }
        int blurredID;
        int blurredID2;

        public GrabPassImpl(Material blurMaterial, Vector2 blurAmount, Material blitMaterial)
        {
            m_BlurMaterial = blurMaterial;
            m_BlitMaterial = blitMaterial;
            m_BlurAmount = blurAmount;
        }

        public void UpdateBlurAmount(Vector2 newBlurAmount)
        {
            m_BlurAmount = newBlurAmount;
        }

        public void Setup(RenderTargetIdentifier source, RenderTargetIdentifier destination)
        {
            this.source = source;
            this.destination = destination;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer buf = CommandBufferPool.Get(k_RenderGrabPassTag);

            using (new ProfilingSample(buf, k_RenderGrabPassTag))
            {
                // copy screen into temporary RT
                int screenCopyID = Shader.PropertyToID("_ScreenCopyTexture");
                RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;


                buf.GetTemporaryRT(screenCopyID, opaqueDesc, FilterMode.Bilinear);
                buf.Blit(source, screenCopyID);

                opaqueDesc.width /= 2;
                opaqueDesc.height /= 2;

                // get two smaller RTs
                blurredID = Shader.PropertyToID("_BlurRT1");
                blurredID2 = Shader.PropertyToID("_BlurRT2");
                buf.GetTemporaryRT(blurredID, opaqueDesc, FilterMode.Bilinear);
                buf.GetTemporaryRT(blurredID2, opaqueDesc, FilterMode.Bilinear);

                // downsample screen copy into smaller RT, release screen RT
                buf.Blit(screenCopyID, blurredID);
                buf.ReleaseTemporaryRT(screenCopyID);
                
                // horizontal blur
                buf.SetGlobalVector("offsets", new Vector4(m_BlurAmount.x / Screen.width, 0, 0, 0));
                buf.Blit(blurredID, blurredID2, m_BlurMaterial);
                // vertical blur
                buf.SetGlobalVector("offsets", new Vector4(0, m_BlurAmount.y / Screen.height, 0, 0));
                buf.Blit(blurredID2, blurredID, m_BlurMaterial);

                // horizontal blur
                buf.SetGlobalVector("offsets", new Vector4(m_BlurAmount.x * 2 / Screen.width, 0, 0, 0));
                buf.Blit(blurredID, blurredID2, m_BlurMaterial);
                // vertical blur
                buf.SetGlobalVector("offsets", new Vector4(0, m_BlurAmount.y * 2 / Screen.height, 0, 0));
                buf.Blit(blurredID2, blurredID, m_BlurMaterial);

                //Set Texture for Shader Graph
                buf.SetGlobalTexture("_GrabBlurTexture", blurredID);


                buf.Blit(source, destination);

                //buf.SetRenderTarget(destination);
            }

            context.ExecuteCommandBuffer(buf);
            CommandBufferPool.Release(buf);

        }

        
        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (cmd == null)
                throw new ArgumentNullException("cmd");

            cmd.ReleaseTemporaryRT(blurredID);
            cmd.ReleaseTemporaryRT(blurredID2);
        }
    }
}